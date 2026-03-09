"""Parse terraform show -json output and write a markdown table to GITHUB_STEP_SUMMARY."""
import json
import os
import sys

SUMMARY   = os.environ.get("GITHUB_STEP_SUMMARY", "/tmp/step_summary.md")
PLAN_JSON = os.environ.get("PLAN_JSON", "ec2.tfplan.json")

SKIP_ATTRS = {
    "id", "arn", "tags_all", "timeouts", "owner_id",
    "availability_zone", "placement_group",
}

try:
    with open(PLAN_JSON) as f:
        plan = json.load(f)
except Exception as e:
    msg = f"## Terraform Plan - EC2 (dev)\n\nFailed to parse plan JSON: {e}\n"
    print(msg)
    open(SUMMARY, "a").write(msg)
    sys.exit(0)


def expand(prefix, bv, av, action):
    """Yield (attr_name, before_str, after_str) – expands dicts (e.g. tags) into per-key rows."""
    if isinstance(bv, dict) or isinstance(av, dict):
        bd = bv if isinstance(bv, dict) else {}
        ad = av if isinstance(av, dict) else {}
        for k in sorted(set(bd) | set(ad)):
            bkv, akv = bd.get(k), ad.get(k)
            if action == "create" and akv not in (None, ""):
                yield f"{prefix}.{k}", "-", str(akv)
            elif action == "delete" and bkv not in (None, ""):
                yield f"{prefix}.{k}", str(bkv), "-"
            elif action not in ("create", "delete") and bkv != akv:
                yield (
                    f"{prefix}.{k}",
                    str(bkv) if bkv is not None else "-",
                    str(akv) if akv is not None else "-",
                )
    else:
        yield (
            prefix,
            str(bv) if bv is not None else "-",
            str(av) if av is not None else "-",
        )


rows = []
for rc in plan.get("resource_changes", []):
    actions   = rc.get("change", {}).get("actions", ["no-op"])
    action    = "replace" if set(actions) == {"create", "delete"} else (actions[0] if actions else "no-op")
    if action == "no-op":
        continue
    address   = rc.get("address", "")
    before    = rc.get("change", {}).get("before") or {}
    after     = rc.get("change", {}).get("after")  or {}

    if action == "create":
        candidates = {k: (None, v) for k, v in after.items()
                      if k not in SKIP_ATTRS and v not in (None, "", [], {})}
    elif action == "delete":
        candidates = {k: (v, None) for k, v in before.items()
                      if k not in SKIP_ATTRS and v not in (None, "", [], {})}
    else:
        candidates = {}
        for k in set(before) | set(after):
            if k in SKIP_ATTRS:
                continue
            bv, av = before.get(k), after.get(k)
            if bv != av:
                candidates[k] = (bv, av)

    for attr, (bv, av) in sorted(candidates.items()):
        for attr_name, bstr, astr in expand(attr, bv, av, action):
            rows.append({
                "action":    action,
                "resource":  address,
                "attribute": attr_name,
                "before":    bstr,
                "after":     astr,
            })


def trunc(val, n=50):
    val = str(val).replace("\n", " ").replace("|", "\\|")
    return val if len(val) <= n else val[:n - 3] + "..."


# ── Markdown table → GITHUB_STEP_SUMMARY ──────────────────────────────────────
with open(SUMMARY, "a") as s:
    s.write("## Terraform Plan - EC2 (dev)\n\n")
    if not rows:
        s.write("No changes - infrastructure is up to date.\n\n")
    else:
        s.write(f"**{len(rows)} change(s)** planned.\n\n")
        s.write("| Action | Resource | Attribute | Before | After |\n")
        s.write("|---|---|---|---|---|\n")
        for r in rows:
            s.write(
                f"| {r['action']} | `{trunc(r['resource'])}` | `{r['attribute']}` "
                f"| `{trunc(r['before'])}` | `{trunc(r['after'])}` |\n"
            )
        s.write("\n")

print(f"Pretty plan written: {len(rows)} change(s)")

# ── Plain-text table → step log ────────────────────────────────────────────────
if not rows:
    print("No changes - infrastructure is up to date.")
else:
    widths  = [10, 30, 25, 25, 25]
    headers = ["ACTION", "RESOURCE", "ATTRIBUTE", "BEFORE", "AFTER"]
    sep     = "+" + "+".join("-" * (w + 2) for w in widths) + "+"

    def row_line(vals):
        parts = []
        for i, v in enumerate(vals):
            cell = str(v).replace("\n", " ")
            w    = widths[i]
            cell = cell if len(cell) <= w else cell[:w - 3] + "..."
            parts.append(f" {cell.ljust(w)} ")
        return "|" + "|".join(parts) + "|"

    print(f"\nTerraform Plan - EC2 (dev) [{len(rows)} change(s)]\n")
    print(sep)
    print(row_line(headers))
    print(sep)
    for r in rows:
        print(row_line([r["action"], r["resource"], r["attribute"], r["before"], r["after"]]))
    print(sep)
    print()
