"""
Generic AWS cost estimator — auto-detects ALL supported resource types in a
Terraform plan JSON and shows a consolidated before/after pricing diff table
in GITHUB_STEP_SUMMARY.

To add pricing for a NEW resource type (e.g. aws_db_instance), just add a
function decorated with @pricer("aws_xxx"). No other changes needed.

Currently supported:
  aws_instance    → EC2 On-Demand (Linux) + EBS gp3 root volume
  aws_db_instance → RDS On-Demand + allocated storage
"""
import json
import os
import sys

import boto3

SUMMARY     = os.environ.get("GITHUB_STEP_SUMMARY", "/tmp/step_summary.md")
PLAN_JSON   = os.environ.get("PLAN_JSON", "ec2.tfplan.json")
LOCATION    = "US East (N. Virginia)"
HOURS_MONTH = 24 * 30

pc = boto3.client("pricing", region_name="us-east-1")

# ── Pricer registry ───────────────────────────────────────────────────────────
PRICERS: dict = {}   # resource_type -> fn(before, after) -> list[7-tuple]

def pricer(resource_type):
    """Decorator that registers a pricing function for a Terraform resource type."""
    def decorator(fn):
        PRICERS[resource_type] = fn
        return fn
    return decorator

# ── Generic AWS Pricing API helper (with simple cache) ────────────────────────
_cache: dict = {}

def fetch_price(service_code, filters: dict) -> float:
    """Return $/unit (On-Demand) for any service + filter combination, cached."""
    key = (service_code, tuple(sorted(filters.items())))
    if key in _cache:
        return _cache[key]
    resp = pc.get_products(
        ServiceCode=service_code,
        Filters=[{"Type": "TERM_MATCH", "Field": k, "Value": v} for k, v in filters.items()],
        MaxResults=1,
    )
    price = 0.0
    if resp["PriceList"]:
        item  = json.loads(resp["PriceList"][0])
        terms = item.get("terms", {}).get("OnDemand", {})
        for term in terms.values():
            for pd in term.get("priceDimensions", {}).values():
                price = float(pd["pricePerUnit"].get("USD", 0))
                break
    _cache[key] = price
    return price

def attr(d, key, default=None):
    """Safe attribute getter — handles None dicts."""
    return (d or {}).get(key, default)

def diff_str(old, new) -> str:
    d = new - old
    if abs(d) < 0.005:
        return "no change"
    sign = "+" if d > 0 else "-"
    return f"{sign}${abs(d):.2f}/mo"

# Each row: (label, before_detail, after_detail, old_$/hr, new_$/hr, old_$/mo, new_$/mo)
# Use 0 for $/hr when the resource is billed per GB/month (storage).

# ── EC2 pricer ────────────────────────────────────────────────────────────────
@pricer("aws_instance")
def price_ec2(before, after) -> list:
    rows = []

    old_itype = attr(before, "instance_type") or attr(after, "instance_type")
    new_itype = attr(after,  "instance_type") or old_itype

    def ec2_hr(itype):
        return fetch_price("AmazonEC2", {
            "instanceType":    itype,
            "operatingSystem": "Linux",
            "location":        LOCATION,
            "tenancy":         "Shared",
            "capacitystatus":  "Used",
            "preInstalledSw":  "NA",
        })

    old_hr = ec2_hr(old_itype)
    new_hr = ec2_hr(new_itype)
    rows.append(("EC2 instance", old_itype, new_itype,
                 old_hr, new_hr, old_hr * HOURS_MONTH, new_hr * HOURS_MONTH))

    # Root EBS (gp3)
    old_gb = next((r.get("volume_size", 0) for r in attr(before, "root_block_device", [])), 0)
    new_gb = next((r.get("volume_size", 0) for r in attr(after,  "root_block_device", [])), old_gb)
    ebs_rate = fetch_price("AmazonEC2", {
        "volumeApiName": "gp3",
        "location":      LOCATION,
        "productFamily": "Storage",
    })
    rows.append(("EBS volume",
                 f"{old_gb} GB gp3", f"{new_gb} GB gp3",
                 0, 0, ebs_rate * old_gb, ebs_rate * new_gb))
    return rows

# ── RDS pricer ────────────────────────────────────────────────────────────────
_ENGINE_MAP = {
    "mysql":              "MySQL",
    "postgres":           "PostgreSQL",
    "mariadb":            "MariaDB",
    "oracle-ee":          "Oracle",
    "oracle-se2":         "Oracle",
    "sqlserver-ee":       "SQL Server",
    "sqlserver-se":       "SQL Server",
    "sqlserver-ex":       "SQL Server",
    "sqlserver-web":      "SQL Server",
    "aurora-mysql":       "Aurora MySQL",
    "aurora-postgresql":  "Aurora PostgreSQL",
}

@pricer("aws_db_instance")
def price_rds(before, after) -> list:
    rows = []

    old_cls    = attr(before, "instance_class") or attr(after, "instance_class", "db.t3.micro")
    new_cls    = attr(after,  "instance_class") or old_cls
    raw_engine = attr(after, "engine") or attr(before, "engine", "mysql")
    engine     = _ENGINE_MAP.get(raw_engine, "MySQL")
    old_dep    = "Multi-AZ" if attr(before, "multi_az", False) else "Single-AZ"
    new_dep    = "Multi-AZ" if attr(after,  "multi_az", False) else "Single-AZ"

    def rds_hr(cls, dep):
        return fetch_price("AmazonRDS", {
            "instanceType":     cls,
            "databaseEngine":   engine,
            "location":         LOCATION,
            "deploymentOption": dep,
        })

    old_hr = rds_hr(old_cls, old_dep)
    new_hr = rds_hr(new_cls, new_dep)
    rows.append((f"RDS {engine}",
                 f"{old_cls} ({old_dep})", f"{new_cls} ({new_dep})",
                 old_hr, new_hr, old_hr * HOURS_MONTH, new_hr * HOURS_MONTH))

    # RDS allocated storage
    old_stor  = attr(before, "allocated_storage", 0) or 0
    new_stor  = attr(after,  "allocated_storage", old_stor) or 0
    old_stype = attr(before, "storage_type", "gp2")
    new_stype = attr(after,  "storage_type", old_stype)
    stor_rate = fetch_price("AmazonRDS", {
        "volumeType":    "General Purpose",
        "location":      LOCATION,
        "productFamily": "Database Storage",
    })
    rows.append(("RDS storage",
                 f"{old_stor} GB {old_stype}", f"{new_stor} GB {new_stype}",
                 0, 0, stor_rate * old_stor, stor_rate * new_stor))
    return rows

# ── Main — read plan, call matching pricers ───────────────────────────────────
try:
    with open(PLAN_JSON) as f:
        plan = json.load(f)
except Exception as e:
    print(f"Failed to read plan JSON: {e}")
    sys.exit(1)

all_rows: list = []

for rc in plan.get("resource_changes", []):
    rtype   = rc.get("type", "")
    actions = rc.get("change", {}).get("actions", [])
    if rtype not in PRICERS or actions == ["no-op"]:
        continue
    before = rc.get("change", {}).get("before") or {}
    after  = rc.get("change", {}).get("after")  or {}
    # For new resources (create), before is empty — default before == after
    if not before:
        before = after
    print(f"Pricing: {rtype} ({', '.join(actions)})")
    all_rows.extend(PRICERS[rtype](before, after))

if not all_rows:
    print("No supported/changed resources found in plan — skipping cost estimate")
    sys.exit(0)

# ── Build and write markdown table ───────────────────────────────────────────
lines = [
    "## AWS Pricing Cost Estimate (dev)\n",
    "| Resource | Before | After | $/hr (old) | $/hr (new) | $/mo (old) | $/mo (new) | Diff |",
    "|---|---|---|---|---|---|---|---|",
]
total_old = total_new = 0.0
for label, bdet, adet, ohr, nhr, omo, nmo in all_rows:
    hr_old = f"${ohr:.4f}" if ohr else "-"
    hr_new = f"${nhr:.4f}" if nhr else "-"
    lines.append(
        f"| {label} | {bdet} | {adet} | {hr_old} | {hr_new} | ${omo:.2f} | ${nmo:.2f} | {diff_str(omo, nmo)} |"
    )
    total_old += omo
    total_new += nmo

lines.append(
    f"| **Total** | | | | | **${total_old:.2f}** | **${total_new:.2f}** | **{diff_str(total_old, total_new)}** |"
)
lines += ["", "> Prices: On-Demand, us-east-1, no Reserved/Savings Plan discount.", ""]

summary = "\n".join(lines) + "\n"
print(summary)
with open(SUMMARY, "a") as s:
    s.write(summary)
