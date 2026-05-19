#!/bin/bash
set -euo pipefail

# Colours
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

info()    { echo -e "${GREEN}[INFO]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }

# Preflight checks 
info "Running preflight checks..."

for cmd in aws docker git; do
  if ! command -v "$cmd" &>/dev/null; then
    error "'$cmd' is not installed or not in PATH."
    exit 1
  fi
done

REQUIRED_VARS=(AWS_REGION ECR_REPOSITORY ASG_NAME)
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    error "Required environment variable '$var' is not set."
    exit 1
  fi
done

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_DIR="$REPO_ROOT/Server/MuchToDo"

IMAGE_TAG="${IMAGE_TAG:-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
ALB_DNS_NAME="${ALB_DNS_NAME:-}"   # optional — skip smoke test if not set

# Derive ECR registry URL
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

info "Image tag      : $IMAGE_TAG"
info "ECR registry   : $ECR_REGISTRY"
info "ECR repository : $ECR_REPOSITORY"
info "ASG name       : $ASG_NAME"

#ECR login 
info "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
success "ECR login successful."

# Build Docker image 
info "Building Docker image from $SERVER_DIR ..."
docker build \
  -t "$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" \
  -t "$ECR_REGISTRY/$ECR_REPOSITORY:latest" \
  "$SERVER_DIR"
success "Docker build complete."

# Push to ECR
info "Pushing $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ..."
docker push "$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
docker push "$ECR_REGISTRY/$ECR_REPOSITORY:latest"
success "Push complete."

# Deploy via SSM 
info "Sending SSM Run Command to ASG '$ASG_NAME'..."

COMMAND_ID=$(aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
  --parameters "commands=[
    \"aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY\",
    \"docker pull $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG\",
    \"docker stop muchtodo-backend 2>/dev/null || true\",
    \"docker rm   muchtodo-backend 2>/dev/null || true\",
    \"docker run -d --name muchtodo-backend --restart unless-stopped -p 8080:8080 --env-file /etc/muchtodo.env $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG\",
    \"docker image prune -f\"
  ]" \
  --query 'Command.CommandId' \
  --output text)

info "SSM command ID: $COMMAND_ID"

# Poll for completion
info "Waiting for SSM command to complete (up to 5 min)..."
for i in $(seq 1 30); do
  STATUS=$(aws ssm list-command-invocations \
    --command-id "$COMMAND_ID" \
    --details \
    --query 'CommandInvocations[*].Status' \
    --output text 2>/dev/null || echo "Pending")

  echo "  Attempt $i — Status: $STATUS"

  if [[ "$STATUS" =~ ^(Success|Failed|Cancelled|TimedOut)$ ]]; then
    if [[ "$STATUS" == "Success" ]]; then
      success "SSM command completed successfully."
      break
    else
      error "SSM command finished with status: $STATUS"
      exit 1
    fi
  fi
  sleep 10
done

# Health check via ALB
if [[ -n "$ALB_DNS_NAME" ]]; then
  info "Running health check against http://$ALB_DNS_NAME/health ..."
  bash "$SCRIPT_DIR/health-check.sh" "http://$ALB_DNS_NAME"
else
  warn "ALB_DNS_NAME not set — skipping smoke test."
fi


echo ""
echo -e "${GREEN}──────────────────────────────────────────${RESET}"
echo -e "${GREEN}  Backend deployment complete!${RESET}"
echo -e "  Image : ${YELLOW}$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG${RESET}"
[[ -n "$ALB_DNS_NAME" ]] && echo -e "  URL   : ${YELLOW}http://$ALB_DNS_NAME${RESET}"
echo -e "${GREEN}──────────────────────────────────────────${RESET}"
