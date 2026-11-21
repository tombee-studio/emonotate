#!/usr/bin/env bash
# Deploy the current checkout, including the checked-out submodule working trees.
set -euo pipefail
case "${1:-}" in
  dev|stg) export ENV="$1" ;;
  prod|prd) export ENV=prd ;;
  *) echo "Usage: $0 dev|stg|prod" >&2; exit 2 ;;
esac
cd "$(dirname "$0")/.."
export AWS_REGION=ap-northeast-1
account=$(aws sts get-caller-identity --query Account --output text)
tf_dir="terraform/environments/$ENV"
repo="emonotate-${ENV}-backend"
function_name="$repo"
export IMAGE_TAG="release-$(date -u +%Y%m%dT%H%M%SZ)-$(uuidgen | cut -c1-8)"
image_uri="${account}.dkr.ecr.${AWS_REGION}.amazonaws.com/${repo}:${IMAGE_TAG}"
export TF_VAR_ecr_image_uri="$image_uri"

# Fail before applying infrastructure if required services or build tools are unavailable.
bash scripts/setup-secrets.sh --ensure
docker info --format '{{.ServerVersion}}' >/dev/null
terraform -chdir="$tf_dir" init -input=false
if ! repo_status=$(aws ecr describe-repositories --repository-names "$repo" --query 'repositories[0].repositoryName' --output text 2>&1); then
  if [[ "$repo_status" != *RepositoryNotFoundException* ]]; then
    echo "$repo_status" >&2
    exit 1
  fi
  terraform -chdir="$tf_dir" apply -target=module.ecr
fi
bash scripts/docker-build-push.sh
terraform -chdir="$tf_dir" apply

aws lambda wait function-updated-v2 --function-name "$function_name"
aws lambda update-function-code --function-name "$function_name" --image-uri "$image_uri" \
  --query FunctionArn --output text
aws lambda wait function-updated-v2 --function-name "$function_name"
bash scripts/run-migrations.sh
API_ENDPOINT=$(terraform -chdir="$tf_dir" output -raw api_endpoint)
CLOUDFRONT_DISTRIBUTION_ID=$(terraform -chdir="$tf_dir" output -raw cloudfront_distribution_id)
export API_ENDPOINT CLOUDFRONT_DISTRIBUTION_ID
export NODE_OPTIONS="${NODE_OPTIONS:---openssl-legacy-provider}"
export CI=false
(cd emonotate-app && npm ci)
bash scripts/deploy-frontend.sh

domain=$(terraform -chdir="$tf_dir" output -raw cloudfront_domain)
curl --fail --silent --show-error "https://${domain}/" | grep -q 'id="root"'
location=$(curl --fail --silent --show-error --output /dev/null --write-out '%{redirect_url}' \
  "https://${domain}/api/cognito/login/")
[[ "$location" == https://*.amazoncognito.com/oauth2/authorize\?* ]]
echo "${ENV} deployed: https://${domain}/"
