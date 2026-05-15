#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="muchtodo-backend"
IMAGE_TAG="latest"

echo "--- Building MuchTodo Docker image ---"
docker build --pull=false -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo ""
echo "Build complete! Image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker images "${IMAGE_NAME}"
