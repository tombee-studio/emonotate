#!/usr/bin/env bash
# Run Django migrations against RDS via a one-shot ECS task or Lambda invoke.
#
# Usage (ECS Fargate one-shot task):
#   ENV=dev CLUSTER=emonotate-dev-cluster TASK_DEF=emonotate-dev-migrate \
#     ./scripts/run-migrations.sh
#
# The ECS task definition should override the command to run:
#   python manage.py migrate --settings=backend.settings.aws
#
# Alternatively, invoke the Lambda directly:
#   ENV=dev ./scripts/run-migrations.sh --lambda

set -euo pipefail

ENV="${ENV:?ENV must be set to dev or prd}"
REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT="emonotate"
MODE="${1:-ecs}"

if [[ "$MODE" == "--lambda" ]]; then
  FUNCTION_NAME="${PROJECT}-${ENV}-backend"
  echo "Invoking Lambda for migrate: ${FUNCTION_NAME} ..."
  aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --cli-binary-format raw-in-base64-out \
    --payload '{"manage": "migrate", "args": ["--noinput"]}' \
    /tmp/migrate-response.json
  cat /tmp/migrate-response.json
else
  CLUSTER="${CLUSTER:?CLUSTER env var required for ECS mode}"
  TASK_DEF="${TASK_DEF:?TASK_DEF env var required for ECS mode}"
  SUBNETS="${SUBNETS:?SUBNETS env var required (comma-separated)}"
  SECURITY_GROUPS="${SECURITY_GROUPS:?SECURITY_GROUPS env var required}"

  echo "Running migrate task on ECS: ${CLUSTER} / ${TASK_DEF} ..."
  TASK_ARN=$(aws ecs run-task \
    --cluster "$CLUSTER" \
    --task-definition "$TASK_DEF" \
    --region "$REGION" \
    --launch-type FARGATE \
    --network-configuration \
      "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SECURITY_GROUPS}],assignPublicIp=DISABLED}" \
    --overrides '{"containerOverrides":[{"name":"backend","command":["python","manage.py","migrate","--noinput","--settings=backend.settings.aws"]}]}' \
    --query "tasks[0].taskArn" \
    --output text)

  echo "Waiting for task to complete: ${TASK_ARN} ..."
  aws ecs wait tasks-stopped \
    --cluster "$CLUSTER" \
    --tasks "$TASK_ARN" \
    --region "$REGION"

  EXIT_CODE=$(aws ecs describe-tasks \
    --cluster "$CLUSTER" \
    --tasks "$TASK_ARN" \
    --region "$REGION" \
    --query "tasks[0].containers[0].exitCode" \
    --output text)

  echo "Migration task exit code: ${EXIT_CODE}"
  exit "$EXIT_CODE"
fi
