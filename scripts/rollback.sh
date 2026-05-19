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

# Configuration 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROLLBACK_TAG="${1:-}"
ALB_DNS_NAME="${ALB_DNS_NAME:-}"

# Validate required environment variables
REQUIRED_VARS=(AWS_REGION ECR_REPOSITORY ASG_NAME)
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    error "Required environment variable '$var' is not set."
    exit 1
  fi
done

# Prompt for tag if not provided as argument
if [[ -z "$ROLLBACK_TAG" ]]; then
  warn "No rollback tag specified."
  echo -n "Enter the image tag to roll back to (e.g. a1b2c3d): "
  read -r ROLLBACK_TAG
fi

if [[ -z "$ROLLBACK_TAG" ]]; then
  error "Rollback tag cannot be empty."
  exit 1
fi

# Derive ECR registry URL
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

echo ""
echo -e "${YELLOW}──────────────────────────────────────────────────────${RESET}"
echo -e "${YELLOW}  ROLLBACK INITIATED${RESET}"
echo -e "  Rolling back to image tag : ${RED}$ROLLBACK_TAG${RESET}"
echo -e "  ECR Registry              : $ECR_REGISTRY"
echo -e "  Repository                : $ECR_REPOSITORY"
echo -e "  ASG                       : $ASG_NAME"
echo -e "${YELLOW}──────────────────────────────────────────────────────${RESET}"
echo ""

# Confirm
echo -n "Proceed with rollback? [y/N] "
read -r CONFIRM
if [[ "${CONFIRM,,}" != "y" ]]; then
  warn "Rollback cancelled."
  exit 0
fi

# ECR login
info "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
success "ECR login successful."

# Verify the target image exists in ECR
info "Verifying image $ECR_REPOSITORY:$ROLLBACK_TAG exists in ECR..."
if ! aws ecr describe-images \
  --repository-name "$ECR_REPOSITORY" \
  --image-ids imageTag="$ROLLBACK_TAG" \
  --region "$AWS_REGION" &>/dev/null; then
  error "Image tag '$ROLLBACK_TAG' not found in ECR repository '$ECR_REPOSITORY'."
  exit 1
fi
success "Image confirmed in ECR."

# Send SSM Run Command
info "Sending rollback SSM command to ASG '$ASG_NAME'..."

COMMAND_ID=$(aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
  --parameters "commands=[
    \"aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY\",
    \"docker pull $ECR_REGISTRY/$ECR_REPOSITORY:$ROLLBACK_TAG\",
    \"docker stop muchtodo-backend 2>/dev/null || true\",
    \"docker rm   muchtodo-backend 2>/dev/null || true\",
    \"docker run -d --name muchtodo-backend --restart unless-stopped -p 8080:8080 --env-file /etc/muchtodo.env $ECR_REGISTRY/$ECR_REPOSITORY:$ROLLBACK_TAG\",
    \"docker image prune -f\"
  ]" \
  --query 'Command.CommandId' \
  --output text)

info "SSM command ID: $COMMAND_ID"

# Poll for completion
info "Waiting for rollback command to complete (up to 5 min)..."
for i in $(seq 1 30); do
  STATUS=$(aws ssm list-command-invocations \
    --command-id "$COMMAND_ID" \
    --details \
    --query 'CommandInvocations[*].Status' \
    --output text 2>/dev/null || echo "Pending")

  echo "  Attempt $i — Status: $STATUS"

  if [[ "$STATUS" =~ ^(Success|Failed|Cancelled|TimedOut)$ ]]; then
    if [[ "$STATUS" == "Success" ]]; then
      success "Rollback SSM command completed."
      break
    else
      error "Rollback SSM command finished with status: $STATUS"
      exit 1
    fi
  fi
  sleep 10
done

# Verify rollback via health check
if [[ -n "$ALB_DNS_NAME" ]]; then
  info "Verifying rollback via health check..."
  bash "$SCRIPT_DIR/health-check.sh" "http://$ALB_DNS_NAME"
else
  warn "ALB_DNS_NAME not set — skipping post-rollback health check."
fi

# Summary
echo ""
echo -e "${GREEN}──────────────────────────────────────────────────────${RESET}"
echo -e "${GREEN}  Rollback complete!${RESET}"
echo -e "  Rolled back to : ${YELLOW}$ECR_REGISTRY/$ECR_REPOSITORY:$ROLLBACK_TAG${RESET}"
[[ -n "$ALB_DNS_NAME" ]] && echo -e "  Endpoint       : ${YELLOW}http://$ALB_DNS_NAME${RESET}"
echo -e "${GREEN}──────────────────────────────────────────────────────${RESET}"
