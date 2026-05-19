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

if ! command -v aws &>/dev/null; then
  error "AWS CLI is not installed. See: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
  exit 1
fi

REQUIRED_VARS=(S3_BUCKET_NAME CLOUDFRONT_DISTRIBUTION_ID AWS_REGION)
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    error "Required environment variable '$var' is not set."
    exit 1
  fi
done

# Locate repo root 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLIENT_DIR="$REPO_ROOT/Client"

if [[ ! -d "$CLIENT_DIR" ]]; then
  error "Client directory not found: $CLIENT_DIR"
  exit 1
fi

#  Build 
info "Installing frontend dependencies..."
(cd "$CLIENT_DIR" && npm ci)

info "Building frontend..."
(cd "$CLIENT_DIR" && npm run build)

DIST_DIR="$CLIENT_DIR/dist"
if [[ ! -d "$DIST_DIR" ]]; then
  error "Build output directory not found: $DIST_DIR"
  exit 1
fi
success "Build complete → $DIST_DIR"

# Sync to S3
info "Syncing static assets to s3://$S3_BUCKET_NAME (long-lived cache)..."
aws s3 sync "$DIST_DIR/" "s3://$S3_BUCKET_NAME" \
  --delete \
  --cache-control "max-age=31536000" \
  --exclude "*.html"

info "Syncing HTML files to s3://$S3_BUCKET_NAME (no-cache)..."
aws s3 sync "$DIST_DIR/" "s3://$S3_BUCKET_NAME" \
  --delete \
  --cache-control "no-cache" \
  --include "*.html" \
  --exclude "*" \
  --metadata-directive REPLACE

success "S3 sync complete."

# Invalidate CloudFront 
info "Invalidating CloudFront distribution $CLOUDFRONT_DISTRIBUTION_ID..."
INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
  --paths "/*" \
  --query 'Invalidation.Id' \
  --output text)

success "CloudFront invalidation created: $INVALIDATION_ID"

echo ""
echo -e "${GREEN}──────────────────────────────────────────${RESET}"
echo -e "${GREEN}  Frontend deployment complete!${RESET}"
echo -e "  S3 Bucket  : ${YELLOW}$S3_BUCKET_NAME${RESET}"
echo -e "  CloudFront : ${YELLOW}https://$CLOUDFRONT_DISTRIBUTION_ID.cloudfront.net${RESET}"
echo -e "${GREEN}──────────────────────────────────────────${RESET}"
