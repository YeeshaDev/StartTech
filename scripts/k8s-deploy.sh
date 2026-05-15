#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="muchtodo-cluster"
IMAGE_NAME="muchtodo-backend:latest"
NAMESPACE="muchtodo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== MuchTodo Kubernetes Deployment ==="

# Create Kind cluster if it doesn't exist 
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "Kind cluster '${CLUSTER_NAME}' already exists — skipping creation."
else
  echo "Creating Kind cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}"
fi

# Switch kubectl context to the new cluster
kubectl cluster-info --context "kind-${CLUSTER_NAME}" > /dev/null

# Build & load image into Kind 
echo ""
if docker image inspect "${IMAGE_NAME}" > /dev/null 2>&1; then
  echo "Docker image '${IMAGE_NAME}' already exists — skipping build."
  echo "(Run 'bash scripts/docker-build.sh' to force a rebuild.)"
else
  echo "Building Docker image..."
  docker build --pull=false -t "${IMAGE_NAME}" "${ROOT_DIR}"
fi

echo "Loading backend image into Kind cluster..."
kind load docker-image "${IMAGE_NAME}" --name "${CLUSTER_NAME}"

echo "Pre-loading MongoDB image into Kind cluster..."
# Save the locally cached image (no network needed)
docker save mongo:7.0 -o /tmp/mongo-kind.tar
docker exec -i "${CLUSTER_NAME}-control-plane" ctr --namespace=k8s.io images import --snapshotter=overlayfs - < /tmp/mongo-kind.tar
rm -f /tmp/mongo-kind.tar

# Apply manifests
echo ""
echo "Applying Kubernetes manifests..."

kubectl apply -f "${ROOT_DIR}/kubernetes/namespace.yaml"

echo "Deploying MongoDB..."
kubectl apply -f "${ROOT_DIR}/kubernetes/mongodb/"

echo "Waiting for MongoDB to be ready (up to 5 min)..."
kubectl rollout status deployment/mongodb -n "${NAMESPACE}" --timeout=300s

echo "Deploying Backend..."
kubectl apply -f "${ROOT_DIR}/kubernetes/backend/"

echo "Waiting for Backend to be ready (up to 2 min)..."
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=120s

echo "Applying Ingress..."
kubectl apply -f "${ROOT_DIR}/kubernetes/ingress.yaml"

# Summary 
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Pods:"
kubectl get pods -n "${NAMESPACE}"
echo ""
echo "Services:"
kubectl get services -n "${NAMESPACE}"
echo ""
echo "To access the API, run in a separate terminal:"
echo "  kubectl port-forward svc/backend-service 8080:80 -n ${NAMESPACE}"
echo ""
echo "Then test with:"
echo "  curl http://localhost:8080/health"
