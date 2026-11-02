#!/usr/bin/env bash
# Smoke test for a deployed ai-gateway. Usage: scripts/smoke-test.sh <venue-suffix>   (dev | test | prod)
# Requires AWS credentials for the target venue, plus the aws and curl CLIs.
set -uo pipefail

VENUE="${1:?usage: smoke-test.sh <dev|test|prod>}"
COMPONENT="${COMPONENT:-litellm-freehealth}"
REGION="${AWS_REGION:-us-west-2}"
PREFIX="/pds/${COMPONENT}"
FAILED=0

check() { if "${@:2}" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; FAILED=1; fi; }
ssm() { aws ssm get-parameter --region "$REGION" --name "${PREFIX}/$1" --query Parameter.Value --output text; }

echo "== SSM interface (${PREFIX})"
for p in s3/config_bucket_name rds/db_endpoint rds/db_secret_arn ecs/master_key_secret_arn \
         iam/ecs_task_role_arn iam/ecs_task_execution_role_arn alb/dns_name ecs/cluster_name ecs/service_name; do
  check "parameter ${p}" ssm "$p"
done

CLUSTER="$(ssm ecs/cluster_name 2>/dev/null)"
SERVICE="$(ssm ecs/service_name 2>/dev/null)"
ALB="$(ssm alb/dns_name 2>/dev/null)"

echo "== ECS service (${CLUSTER}/${SERVICE})"
RUNNING="$(aws ecs describe-services --region "$REGION" --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].[runningCount,desiredCount]' --output text 2>/dev/null | tr '\t' '/')"
echo "running/desired: ${RUNNING:-unknown}"
check "running count equals desired count" test "${RUNNING%/*}" = "${RUNNING#*/}" -a -n "${RUNNING%/*}"

echo "== Load balancer (${ALB})"
check "GET /health/readiness returns 200" test "$(curl -s -m 10 -o /dev/null -w '%{http_code}' "http://${ALB}/health/readiness")" = "200"

if [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  check "GET /v1/models with ANTHROPIC_AUTH_TOKEN returns 200" \
    test "$(curl -s -m 10 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}" "http://${ALB}/v1/models")" = "200"
else
  echo "SKIP  /v1/models (set ANTHROPIC_AUTH_TOKEN to a master or virtual key to enable)"
fi

echo
[ "$FAILED" -eq 0 ] && echo "SMOKE TEST PASSED (${VENUE})" || { echo "SMOKE TEST FAILED (${VENUE})"; exit 1; }
