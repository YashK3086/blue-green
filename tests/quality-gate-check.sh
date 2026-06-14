
#!/bin/bash
# ============================================================
# DevOps-Blue-Green | SonarQube Quality Gate Check
# quality-gate-check.sh
#
# Usage: ./quality-gate-check.sh <SONAR_HOST_URL> <SONAR_TOKEN> <PROJECT_KEY>
# Called by Jenkins after the sonar-scanner finishes.
# Exits with 0 (pass) or 1 (fail) to block/allow the pipeline.
# ============================================================

set -e

SONAR_HOST_URL="${1:-$SONAR_HOST_URL}"
SONAR_TOKEN="${2:-$SONAR_TOKEN}"
PROJECT_KEY="${3:-devops-blue-green}"
MAX_RETRIES=20
SLEEP_SECONDS=15

echo "=================================================="
echo " [SAST] SonarQube Quality Gate Check"
echo " Project  : ${PROJECT_KEY}"
echo " Host     : ${SONAR_HOST_URL}"
echo "=================================================="

# Poll the SonarQube API until the task is complete
for i in $(seq 1 $MAX_RETRIES); do
  echo "[Attempt ${i}/${MAX_RETRIES}] Querying Quality Gate status..."

  RESPONSE=$(curl -s -u "${SONAR_TOKEN}:" \
    "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=${PROJECT_KEY}")

  STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['projectStatus']['status'])" 2>/dev/null || echo "UNKNOWN")

  echo " Quality Gate Status: ${STATUS}"

  if [ "$STATUS" = "OK" ]; then
    echo "--------------------------------------------------"
    echo " ✅ Quality Gate PASSED. Proceeding with pipeline."
    echo "--------------------------------------------------"
    exit 0
  elif [ "$STATUS" = "ERROR" ]; then
    echo "--------------------------------------------------"
    echo " ❌ Quality Gate FAILED. Blocking deployment."
    echo " Fix the reported issues in SonarQube UI at:"
    echo " ${SONAR_HOST_URL}/dashboard?id=${PROJECT_KEY}"
    echo "--------------------------------------------------"
    exit 1
  else
    echo " Status is '${STATUS}'. Waiting ${SLEEP_SECONDS}s..."
    sleep $SLEEP_SECONDS
  fi
done

echo " ⚠️  Quality Gate check timed out after ${MAX_RETRIES} retries."
exit 1
