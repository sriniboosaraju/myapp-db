"""Fetch AWS On-Demand pricing for the planned EC2 instance and EBS volume,
then write a cost-estimate markdown table to GITHUB_STEP_SUMMARY."""
import json
import os
import sys

import boto3

SUMMARY   = os.environ.get("GITHUB_STEP_SUMMARY", "/tmp/step_summary.md")
PLAN_JSON = os.environ.get("PLAN_JSON", "ec2.tfplan.json")

# ── Read instance type and EBS size from plan JSON ────────────────────────────
try:
    with open(PLAN_JSON) as f:
        plan = json.load(f)
except Exception as e:
    print(f"Failed to read plan JSON: {e}")
    sys.exit(1)

instance_type = None
ebs_gb        = 0

for rc in plan.get("resource_changes", []):
    if rc.get("type") == "aws_instance":
        after         = rc.get("change", {}).get("after") or {}
        instance_type = after.get("instance_type", "t3.micro")
        for rbd in after.get("root_block_device", []):
            ebs_gb = rbd.get("volume_size", 0)
        break

if not instance_type:
    print("No aws_instance found in plan – skipping cost estimate")
    sys.exit(0)

print(f"Instance type : {instance_type}")
print(f"Root EBS (gp3): {ebs_gb} GB")

# ── AWS Pricing API (only available in us-east-1) ─────────────────────────────
pc = boto3.client("pricing", region_name="us-east-1")

resp = pc.get_products(
    ServiceCode="AmazonEC2",
    Filters=[
        {"Type": "TERM_MATCH", "Field": "instanceType",   "Value": instance_type},
        {"Type": "TERM_MATCH", "Field": "operatingSystem","Value": "Linux"},
        {"Type": "TERM_MATCH", "Field": "location",       "Value": "US East (N. Virginia)"},
        {"Type": "TERM_MATCH", "Field": "tenancy",        "Value": "Shared"},
        {"Type": "TERM_MATCH", "Field": "capacitystatus", "Value": "Used"},
        {"Type": "TERM_MATCH", "Field": "preInstalledSw", "Value": "NA"},
    ],
    MaxResults=1,
)

ec2_hourly = 0.0
if resp["PriceList"]:
    item  = json.loads(resp["PriceList"][0])
    terms = item.get("terms", {}).get("OnDemand", {})
    for term in terms.values():
        for pd in term.get("priceDimensions", {}).values():
            ec2_hourly = float(pd["pricePerUnit"].get("USD", 0))
            break

ebs_resp = pc.get_products(
    ServiceCode="AmazonEC2",
    Filters=[
        {"Type": "TERM_MATCH", "Field": "volumeApiName", "Value": "gp3"},
        {"Type": "TERM_MATCH", "Field": "location",      "Value": "US East (N. Virginia)"},
        {"Type": "TERM_MATCH", "Field": "productFamily", "Value": "Storage"},
    ],
    MaxResults=1,
)

ebs_per_gb_month = 0.0
if ebs_resp["PriceList"]:
    item  = json.loads(ebs_resp["PriceList"][0])
    terms = item.get("terms", {}).get("OnDemand", {})
    for term in terms.values():
        for pd in term.get("priceDimensions", {}).values():
            ebs_per_gb_month = float(pd["pricePerUnit"].get("USD", 0))
            break

# ── Calculate and write summary ───────────────────────────────────────────────
ec2_monthly   = ec2_hourly * 24 * 30
ebs_monthly   = ebs_per_gb_month * ebs_gb
total_monthly = ec2_monthly + ebs_monthly

summary = (
    "## AWS Pricing Cost Estimate - EC2 (dev)\n\n"
    "| Resource | Detail | $/hr | $/month |\n"
    "|---|---|---|---|\n"
    f"| EC2 instance | {instance_type} (On-Demand Linux) | ${ec2_hourly:.4f} | ${ec2_monthly:.2f} |\n"
    f"| EBS volume | {ebs_gb} GB gp3 | - | ${ebs_monthly:.2f} |\n"
    f"| **Total** | | | **${total_monthly:.2f}** |\n\n"
    "> Prices: On-Demand, us-east-1, no Reserved/Savings Plan discount.\n\n"
)

print(summary)
with open(SUMMARY, "a") as s:
    s.write(summary)
