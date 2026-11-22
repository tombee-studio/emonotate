#!/usr/bin/env bash
# Initialize schema and the existing application roles in the selected Neon database.
set -euo pipefail
: "${ENV:?Set ENV to dev, stg or prd}"
response=$(mktemp)
trap 'rm -f "$response"' EXIT
aws lambda invoke --cli-read-timeout 210 --function-name "emonotate-${ENV}-backend" \
  --region "${AWS_REGION:-ap-northeast-1}" --cli-binary-format raw-in-base64-out \
  --payload '{"manage":"migrate --fake-initial --noinput"}' "$response" >/dev/null
jq -er 'if .status == "ok" then .output else error(.error // .errorMessage // "Migration failed") end' "$response"
