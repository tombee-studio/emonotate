#!/usr/bin/env bash
# Verify that the AWS environment is working end-to-end.
#
# Usage:
#   ENV=dev ./scripts/e2e-verify.sh
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - curl, jq installed

set -euo pipefail

ENV="${ENV:?ENV must be set to dev, stg or prd}"
REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT="emonotate"

PASS=0
FAIL=0

pass() { echo "[PASS] $1"; ((++PASS)); }
fail() { echo "[FAIL] $1"; ((++FAIL)); }

# --- 1. Lambda health check ---
echo "=== Lambda ==="
FUNCTION="${PROJECT}-${ENV}-backend"
STATUS=$(aws lambda get-function \
  --function-name "$FUNCTION" \
  --region "$REGION" \
  --query "Configuration.State" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$STATUS" == "Active" ]]; then
  pass "Lambda function is Active"
else
  fail "Lambda function state: ${STATUS}"
fi

# --- 2. API Gateway health check ---
echo ""
echo "=== API Gateway ==="
API_ID=$(aws apigatewayv2 get-apis \
  --region "$REGION" \
  --query "Items[?Name=='${PROJECT}-${ENV}-api'].ApiId" \
  --output text 2>/dev/null || echo "")

if [[ -n "$API_ID" && "$API_ID" != "None" ]]; then
  pass "API Gateway found: ${API_ID}"
  API_ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com"

  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 15 "${API_ENDPOINT}/api/" || echo "000")
  if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "401" || "$HTTP_STATUS" == "403" ]]; then
    pass "API endpoint responds: HTTP ${HTTP_STATUS}"
  else
    fail "API endpoint returned: HTTP ${HTTP_STATUS}"
  fi
else
  fail "API Gateway not found"
fi

# Starting a Cognito flow writes its state to a database-backed session.
if [[ -n "${API_ENDPOINT:-}" ]]; then
  location=$(curl -fsS --max-time 20 -o /dev/null -w '%{redirect_url}' \
    "${API_ENDPOINT}/api/cognito/login/" || true)
  if [[ "$location" == https://*.amazoncognito.com/oauth2/authorize\?* ]]; then
    pass "Neon session and Cognito redirect"
  else
    fail "Could not start Cognito sign-in"
  fi
fi
if aws s3api head-bucket --bucket "${PROJECT}-${ENV}-media" >/dev/null 2>&1; then
  pass "S3 media bucket exists"
else
  fail "S3 media bucket unavailable"
fi

# --- 4. S3 frontend bucket ---
echo ""
echo "=== S3 / CloudFront ==="
BUCKET="${PROJECT}-${ENV}-frontend"
BUCKET_EXISTS=$(aws s3api head-bucket --bucket "$BUCKET" 2>&1 || echo "MISSING")
if [[ -z "$BUCKET_EXISTS" ]]; then
  pass "Frontend S3 bucket exists: ${BUCKET}"
  OBJECT_COUNT=$(aws s3 ls "s3://${BUCKET}" --recursive | wc -l | tr -d ' ')
  if [[ "$OBJECT_COUNT" -gt 0 ]]; then
    pass "Frontend bucket has ${OBJECT_COUNT} objects"
  else
    fail "Frontend bucket is empty (deploy not run yet?)"
  fi
else
  fail "Frontend S3 bucket not found: ${BUCKET}"
fi

CF_DOMAIN=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Origins.Items[0].DomainName=='${BUCKET}.s3.${REGION}.amazonaws.com'].DomainName" \
  --output text 2>/dev/null || echo "")

if [[ -n "$CF_DOMAIN" && "$CF_DOMAIN" != "None" ]]; then
  pass "CloudFront distribution found: ${CF_DOMAIN}"
  CF_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 15 "https://${CF_DOMAIN}/" || echo "000")
  if [[ "$CF_STATUS" == "200" ]]; then
    pass "CloudFront responds: HTTP ${CF_STATUS}"
  else
    fail "CloudFront returned: HTTP ${CF_STATUS}"
  fi
else
  fail "CloudFront distribution not found"
fi

# --- 5. ECR check ---
echo ""
echo "=== ECR ==="
REPO="${PROJECT}-${ENV}-backend"
IMAGE_COUNT=$(aws ecr list-images \
  --repository-name "$REPO" \
  --region "$REGION" \
  --query "length(imageIds)" \
  --output text 2>/dev/null || echo "0")

if [[ "$IMAGE_COUNT" -gt 0 ]]; then
  pass "ECR has ${IMAGE_COUNT} image(s) in ${REPO}"
else
  fail "ECR repository has no images (build not run yet?)"
fi

# --- Summary ---
echo ""
echo "==============================="
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "==============================="
[[ "$FAIL" -eq 0 ]]
