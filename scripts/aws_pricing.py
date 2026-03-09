"""Fetch AWS On-Demand pricing for old and new EC2 instance types from the plan,
show a before/after cost diff table in GITHUB_STEP_SUMMARY."""
import json
import os
import sys

import boto3

SUMMARY   = os.environ.get("GITHUB_STEP_SUMMARY", "/tmp/step_summary.md")
PLAN_JSON = os.environ.get("PLAN_JSON", "ec2.tfplan.json")

# ── Read before/after instance type and EBS size from plan JSON ───────────────
try:
    with open(PLAN_JSON) as f:
        plan = json.load(f)
except Exception as e:
    print(f"Failed to read plan JSON: {e}")
    sys.exit(1)

old_instance_type = None
new_instance_type = None
old_ebs_gb        = 0
new_ebs_gb        = 0

for rc in plan.get("resource_changes", []):
    if rc.get("type") == "aws_instance":
        before = rc.get("change", {}).get("before") or {}
        after  = rc.get("change", {}).get("after")  or {}
        old_instance_type = before.get("instance_type")
        new_instance_type = after.get("instance_type")
        for rbd in before.get("root_block_device", []):
            old_ebs_gb = rbd.get("volume_size", 0)
        for rbd in after.get("root_block_device", []):
            new_ebs_gb = rbd.get("volume_size", 0)
        break

if not new_instance_type:
    print("No aws_instance found in plan - skipping cost estimate")
    sys.exit(0)

# If no before state (new resource), treat old == new for display
if not old_instance_type:
    old_instance_type = new_instance_type
    old_ebs_gb        = new_ebs_gb

print(f"Instance type : {old_instance_type} -> {new_instance_type}")
print(f"EBS (gp3) GB  : {old_ebs_gb} -> {new_ebs_gb}")

# ── Fetch EC2 On-Demand price for a given instance type ───────────────────────
pc = boto3.client("pricing", region_name="us-east-1")

def get_ec2_hourly(itype):
    resp = pc.get_products(
        ServiceCode="AmazonEC2",
        Filters=[
            {"Type": "TERM_MATCH", "Field": "instanceType",    "Value": itype},
            {"Type": "TERM_MATCH", "Field": "operatingSystem", "Value": "Linux"},
            {"Type": "TERM_MATCH", "Field": "location",        "Value": "US East (N. Virginia)"},
            {"Type": "TERM_MATCH", "Field": "tenancy",         "Value": "Shared"},
            {"Type": "TERM_MATCH", "Field": "capacitystatus",  "Value": "Used"},
            {"Type": "TERM_MATCH", "Field": "preInstalledSw",  "Value": "NA"},
        ],
        MaxResults=1,
    )
    if resp["PriceList"]:
        item  = json.loads(resp["PriceList"][0])
        terms = item.get("terms", {}).get("OnDemand", {})
        for term in terms.values():
            for pd in term.get("priceDimensions", {}).values():
                return float(pd["pricePerUnit"].get("USD", 0))
    return 0.0

# ── Fetch EBS gp3 per-GB-month price ─────────────────────────────────────────
def get_ebs_per_gb():
    resp = pc.get_products(
        ServiceCode="AmazonEC2",
        Filters=[
            {"Type": "TERM_MATCH", "Field": "volumeApiName", "Value": "gp3"},
            {"Type": "TERM_MATCH", "Field": "location",      "Value": "US East (N. Virginia)"},
            {"Type": "TERM_MATCH", "Field": "productFamily", "Value": "Storage"},
        ],
        MaxResults=1,
    )
    if resp["PriceList"]:
        item  = json.loads(resp["PriceList"][0])
        terms = item.get("terms", {}).get("OnDemand", {})
        for term in terms.values():
            for pd in term.get("priceDimensions", {}).values():
                return float(pd["pricePerUnit"].get("USD", 0))
    return 0.0

old_ec2_hr   = get_ec2_hourly(old_instance_type)
new_ec2_hr   = get_ec2_hourly(new_instance_type)
ebs_per_gb   = get_ebs_per_gb()

# ── Calculate monthly costs ───────────────────────────────────────────────────
HOURS_MONTH = 24 * 30

old_ec2_mo  = old_ec2_hr * HOURS_MONTH
new_ec2_mo  = new_ec2_hr * HOURS_MONTH
old_ebs_mo  = ebs_per_gb * old_ebs_gb
new_ebs_mo  = ebs_per_gb * new_ebs_gb
old_total   = old_ec2_mo + old_ebs_mo
new_total   = new_ec2_mo + new_ebs_mo
diff_total  = new_total - old_total

def diff_str(old, new):
    d = new - old
    if abs(d) < 0.0001:
        return "no change"
    sign = "+" if d > 0 else "-"
    return f"{sign}${abs(d):.2f}/mo"

def arrow(old_val, new_val):
    """Return formatted cell showing old -> new, or just the value if unchanged."""
    if old_val == new_val:
        return str(old_val)
    return f"{old_val} -> {new_val}"

summary = (
    "## AWS Pricing Cost Estimate - EC2 (dev)\n\n"
    "| Resource | Before | After | $/hr (old) | $/hr (new) | $/mo (old) | $/mo (new) | Diff |\n"
    "|---|---|---|---|---|---|---|---|\n"
    f"| EC2 instance | {old_instance_type} | {new_instance_type} | "
    f"${old_ec2_hr:.4f} | ${new_ec2_hr:.4f} | "
    f"${old_ec2_mo:.2f} | ${new_ec2_mo:.2f} | "
    f"{diff_str(old_ec2_mo, new_ec2_mo)} |\n"
    f"| EBS volume | {old_ebs_gb} GB gp3 | {new_ebs_gb} GB gp3 | "
    f"- | - | "
    f"${old_ebs_mo:.2f} | ${new_ebs_mo:.2f} | "
    f"{diff_str(old_ebs_mo, new_ebs_mo)} |\n"
    f"| **Total** | | | | | **${old_total:.2f}** | **${new_total:.2f}** | "
    f"**{diff_str(old_total, new_total)}** |\n\n"
    "> Prices: On-Demand, us-east-1, no Reserved/Savings Plan discount.\n\n"
)

print(summary)
with open(SUMMARY, "a") as s:
    s.write(summary)
