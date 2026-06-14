#!/usr/bin/env bash
# Build the backend Docker image and push it to ECR.
#
# Usage:
#   ENV=dev ./scripts/docker-build-push.sh
#   ENV=dev IMAGE_TAG=v1.2.3 ./scripts/docker-build-push.sh
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Docker installed and running

set -euo pipefail

ENV="${ENV:?ENV must be set to dev or prd}"
REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT="emonotate"
IMAGE_TAG="${IMAGE_TAG:-$(git -C emonotate-backend rev-parse --short HEAD 2>/dev/null || echo latest)}"
REPO_NAME="${PROJECT}-${ENV}-backend"

echo "Fetching ECR account ID ..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
FULL_IMAGE="${REGISTRY}/${REPO_NAME}"

echo "Authenticating Docker to ECR ..."
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo "Building image: ${FULL_IMAGE}:${IMAGE_TAG} ..."
docker build \
  -f emonotate-backend/Dockerfile.aws \
  -t "${FULL_IMAGE}:${IMAGE_TAG}" \
  -t "${FULL_IMAGE}:latest" \
  emonotate-backend/

echo "Pushing image to ECR ..."
docker push "${FULL_IMAGE}:${IMAGE_TAG}"
docker push "${FULL_IMAGE}:latest"

echo "Push complete: ${FULL_IMAGE}:${IMAGE_TAG}"
