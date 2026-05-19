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
BASE_URL="${1:-http://localhost:8080}"
HEALTH_URL="${BASE_URL%/}/health"
MAX_RETRIES=10
RETRY_DELAY=10

info "Health-check URL : $HEALTH_URL"
info "Max retries      : $MAX_RETRIES  (${RETRY_DELAY}s delay)"

# Poll 
for attempt in $(seq 1 "$MAX_RETRIES"); do
  echo ""
  info "Attempt $attempt / $MAX_RETRIES ..."

  HTTP_STATUS=$(curl -s -o /tmp/health_response.json -w "%{http_code}" \
    --max-time 5 "$HEALTH_URL" 2>/dev/null || echo "000")

  if [[ "$HTTP_STATUS" == "200" ]]; then
    echo ""
    success "Service is healthy (HTTP $HTTP_STATUS)"

    # Parse and display component status if jq is available
    if command -v jq &>/dev/null; then
      echo ""
      echo -e "  Component status:"
      DB_STATUS=$(jq -r '.database // "unknown"' /tmp/health_response.json 2>/dev/null || echo "unknown")
      CACHE_STATUS=$(jq -r '.cache // "unknown"' /tmp/health_response.json 2>/dev/null || echo "unknown")

      if [[ "$DB_STATUS" == "ok" ]]; then
        echo -e "    Database : ${GREEN}$DB_STATUS${RESET}"
      else
        echo -e "    Database : ${RED}$DB_STATUS${RESET}"
      fi

      if [[ "$CACHE_STATUS" == "ok" ]]; then
        echo -e "    Cache    : ${GREEN}$CACHE_STATUS${RESET}"
      elif [[ "$CACHE_STATUS" == "disabled" ]]; then
        echo -e "    Cache    : ${YELLOW}$CACHE_STATUS${RESET}"
      else
        echo -e "    Cache    : ${RED}$CACHE_STATUS${RESET}"
      fi
    else
      warn "jq not found — raw response:"
      cat /tmp/health_response.json
    fi

    exit 0

  elif [[ "$HTTP_STATUS" == "503" ]]; then
    warn "Service degraded (HTTP 503) — one or more components are down."
    if command -v jq &>/dev/null; then
      jq '.' /tmp/health_response.json 2>/dev/null || true
    fi

  elif [[ "$HTTP_STATUS" == "000" ]]; then
    warn "No response / connection refused."

  else
    warn "Unexpected HTTP status: $HTTP_STATUS"
    cat /tmp/health_response.json 2>/dev/null || true
  fi

  if [[ "$attempt" -lt "$MAX_RETRIES" ]]; then
    info "Retrying in ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
  fi
done

echo ""
error "Health check failed after $MAX_RETRIES attempts."
exit 1
