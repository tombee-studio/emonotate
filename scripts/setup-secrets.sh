#!/usr/bin/env bash
# Register required secrets in AWS Secrets Manager.
# Run once per environment before deploying.
#
# Usage:
#   ENV=dev ./scripts/setup-secrets.sh
#   ENV=prd ./scripts/setup-secrets.sh
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - jq installed

set -euo pipefail

ENV="${ENV:?ENV must be set to dev or prd}"
REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT="emonotate"
SECRET_NAME="${PROJECT}-${ENV}-django"

echo "Creating secret '${SECRET_NAME}' in ${REGION} ..."

read -r -p "DJANGO_SECRET_KEY: " DJANGO_SECRET_KEY
read -r -p "DB_HOST (RDS endpoint): " DB_HOST
read -r -p "DB_NAME [emonotate]: " DB_NAME
DB_NAME="${DB_NAME:-emonotate}"
read -r -p "DB_USER [emonotate]: " DB_USER
DB_USER="${DB_USER:-emonotate}"
read -r -s -p "DB_PASSWORD: " DB_PASSWORD
echo ""

SECRET_JSON=$(jq -n \
  --arg key "$DJANGO_SECRET_KEY" \
  --arg host "$DB_HOST" \
  --arg name "$DB_NAME" \
  --arg user "$DB_USER" \
  --arg pass "$DB_PASSWORD" \
  '{
    DJANGO_SECRET_KEY: $key,
    DB_HOST:           $host,
    DB_NAME:           $name,
    DB_USER:           $user,
    DB_PASSWORD:       $pass,
    DB_PORT:           "5432"
  }')

if aws secretsmanager describe-secret \
      --secret-id "$SECRET_NAME" \
      --region "$REGION" &>/dev/null; then
  echo "Secret already exists. Updating value ..."
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$REGION" \
    --secret-string "$SECRET_JSON"
else
  echo "Creating new secret ..."
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --region "$REGION" \
    --description "Django settings for emonotate ${ENV}" \
    --secret-string "$SECRET_JSON" \
    --tags "[{\"Key\":\"Project\",\"Value\":\"${PROJECT}\"},{\"Key\":\"Env\",\"Value\":\"${ENV}\"}]"
fi

echo "Done. Set the Lambda env var: DJANGO_SECRET_NAME=${SECRET_NAME}"
