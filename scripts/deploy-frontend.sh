#!/usr/bin/env bash
# Build the React frontend and deploy it to S3 + CloudFront.
#
# Usage:
#   ENV=dev API_ENDPOINT=https://xxx.execute-api.ap-northeast-1.amazonaws.com \
#     ./scripts/deploy-frontend.sh
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Node.js and npm installed

set -euo pipefail

ENV="${ENV:?ENV must be set to dev or prd}"
REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT="emonotate"
API_ENDPOINT="${API_ENDPOINT:?API_ENDPOINT must be set to the API Gateway URL}"

BUCKET_NAME="${PROJECT}-${ENV}-frontend"
APP_DIR="emonotate-app"

echo "Fetching CloudFront distribution ID for bucket ${BUCKET_NAME} ..."
CF_DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Origins.Items[0].DomainName=='${BUCKET_NAME}.s3.ap-northeast-1.amazonaws.com'].Id" \
  --output text)

echo "Building frontend for ${ENV} environment ..."
cd "$APP_DIR"

REACT_APP_API_URL="$API_ENDPOINT" \
REACT_APP_ENV="$ENV" \
  npm run build

echo "Syncing build to S3: s3://${BUCKET_NAME} ..."
aws s3 sync build/ "s3://${BUCKET_NAME}" \
  --delete \
  --region "$REGION" \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html"

aws s3 cp build/index.html "s3://${BUCKET_NAME}/index.html" \
  --region "$REGION" \
  --cache-control "no-cache, no-store, must-revalidate"

cd ..

if [[ -n "$CF_DIST_ID" ]]; then
  echo "Invalidating CloudFront cache for distribution: ${CF_DIST_ID} ..."
  aws cloudfront create-invalidation \
    --distribution-id "$CF_DIST_ID" \
    --paths "/*"
  echo "Cache invalidation initiated."
else
  echo "WARNING: CloudFront distribution not found. Skipping invalidation."
fi

echo "Frontend deployed to s3://${BUCKET_NAME}"
