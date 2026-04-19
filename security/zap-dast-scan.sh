
#!/bin/bash
# ============================================================
# DevOps-Blue-Green | OWASP ZAP DAST Runner
# zap-dast-scan.sh
#
# Purpose:
#   Runs a ZAP Baseline scan against the Argo Preview URL
#   (the "Green" environment before traffic promotion).
#   Outputs a JSON report and sets the exit code:
#     Exit 0 = No High vulnerabilities → pipeline continues
#     Exit 1 = High vulnerabilities found → triggers rollback
#
# Called from the Jenkins pipeline AFTER the Green preview
# is live and BEFORE 'argo rollouts promote'.
#
# Usage:
#   ./zap-dast-scan.sh <TARGET_URL>
#
# Requires: Docker (ZAP runs as a container - no install needed)
# ============================================================

set -e

TARGET_URL="${1:-$PREVIEW_URL}"
ZAP_REPORT_DIR="/tmp/bg-zap-reports"
ZAP_REPORT_JSON="bg-zap-report.json"
ZAP_REPORT_HTML="bg-zap-report.html"
ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable"

echo "============================================================"
echo " [DAST] OWASP ZAP Baseline Scan"
echo " Target URL  : ${TARGET_URL}"
echo " ZAP Image   : ${ZAP_IMAGE}"
echo " Report Dir  : ${ZAP_REPORT_DIR}"
echo "============================================================"

# --- Step 1: Prepare report output directory on host ---
mkdir -p "${ZAP_REPORT_DIR}"
# ZAP container runs as user 1000; make dir world-writable so it can write reports
chmod 777 "${ZAP_REPORT_DIR}"

# --- Step 2: Run ZAP Baseline Scan ---
# The baseline scan is fast (spider + passive scan) and is ideal for CI/CD gates.
# We use the JSON report to parse for "High" risk alerts programmatically.
echo "[ZAP] Starting scan against ${TARGET_URL}..."

docker run --rm \
  -v "${ZAP_REPORT_DIR}:/zap/wrk/:rw" \
  -t "${ZAP_IMAGE}" \
  zap-baseline.py \
    -t "${TARGET_URL}" \
    -J "${ZAP_REPORT_JSON}" \
    -r "${ZAP_REPORT_HTML}" \
    -l WARN \
    --auto \
    -I  # -I = do not fail on warnings; we control failure below via our own check

ZAP_EXIT_CODE=$?
echo "[ZAP] Scan complete. Exit code from ZAP: ${ZAP_EXIT_CODE}"

# --- Step 3: Parse JSON report for HIGH-risk alerts ---
echo "[ZAP] Parsing report for HIGH-risk vulnerabilities..."

HIGH_COUNT=$(python3 -c "
import json, sys

report_path = '${ZAP_REPORT_DIR}/${ZAP_REPORT_JSON}'
try:
    with open(report_path, 'r') as f:
        data = json.load(f)
    high = [
        alert for site in data.get('site', [])
        for alert in site.get('alerts', [])
        if alert.get('riskcode', '0') == '3'   # riskcode 3 = HIGH in ZAP JSON
    ]
    print(len(high))
    for a in high:
        print(f\"  [HIGH] {a.get('alert', 'Unknown')} | CWE: {a.get('cweid', 'N/A')} | URL: {a.get('instances', [{}])[0].get('uri', 'N/A')}\", file=sys.stderr)
except Exception as e:
    print(0)
    print(f'Warning: Could not parse report: {e}', file=sys.stderr)
")

echo "[ZAP] HIGH-risk vulnerabilities found: ${HIGH_COUNT}"

# --- Step 4: Enforce Security Gate ---
if [ "${HIGH_COUNT}" -gt "0" ]; then
  echo "============================================================"
  echo " ❌ DAST GATE FAILED: ${HIGH_COUNT} HIGH-risk alert(s) found."
  echo " The Argo Rollout will NOT be promoted."
  echo " Review the full report at:"
  echo "   ${ZAP_REPORT_DIR}/${ZAP_REPORT_HTML}"
  echo "============================================================"
  exit 1
else
  echo "============================================================"
  echo " ✅ DAST GATE PASSED: No HIGH-risk vulnerabilities detected."
  echo " Argo Rollout promotion may proceed."
  echo "============================================================"
  exit 0
fi
