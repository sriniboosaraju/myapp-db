"""Parse Trivy JSON output and write a markdown table to GITHUB_STEP_SUMMARY."""
import json
import os
import sys

SUMMARY = os.environ.get("GITHUB_STEP_SUMMARY", "/tmp/step_summary.md")
TRIVY_JSON = os.environ.get("TRIVY_JSON", "/tmp/trivy.json")

try:
    with open(TRIVY_JSON) as f:
        data = json.load(f)
except Exception as e:
    with open(SUMMARY, "a") as s:
        s.write(f"## Trivy Security Scan - EC2 (dev)\n\nFailed to parse results: {e}\n")
    sys.exit(0)

rows = []
for result in data.get("Results", []):
    for m in result.get("Misconfigurations", []):
        rows.append({
            "severity": m.get("Severity", "UNKNOWN"),
            "id":       m.get("ID", ""),
            "title":    m.get("Title", ""),
            "resource": result.get("Target", ""),
            "status":   m.get("Status", ""),
        })

order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "UNKNOWN": 4}
rows.sort(key=lambda r: order.get(r["severity"].upper(), 5))

severity_icon = {
    "CRITICAL": ":red_circle:",
    "HIGH":     ":orange_circle:",
    "MEDIUM":   ":yellow_circle:",
    "LOW":      ":blue_circle:",
    "UNKNOWN":  ":white_circle:",
}

with open(SUMMARY, "a") as s:
    s.write("## Trivy Security Scan - EC2 (dev)\n\n")
    if not rows:
        s.write(":white_check_mark: No misconfigurations found.\n\n")
    else:
        s.write(f"**{len(rows)} finding(s)** detected.\n\n")
        s.write("| Severity | ID | Title | Resource | Status |\n")
        s.write("|---|---|---|---|---|\n")
        for r in rows:
            icon = severity_icon.get(r["severity"].upper(), ":white_circle:")
            s.write(
                f"| {icon} {r['severity']} | `{r['id']}` | {r['title']} "
                f"| `{r['resource']}` | {r['status']} |\n"
            )
        s.write("\n")

print(f"Trivy summary written: {len(rows)} finding(s)")
