#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="muchtodo-cluster"
NAMESPACE="muchtodo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Cleaning up MuchTodo Kubernetes resources ==="

kubectl delete -f "${ROOT_DIR}/kubernetes/ingress.yaml"        --ignore-not-found
kubectl delete -f "${ROOT_DIR}/kubernetes/backend/"            --ignore-not-found
kubectl delete -f "${ROOT_DIR}/kubernetes/mongodb/"            --ignore-not-found
kubectl delete -f "${ROOT_DIR}/kubernetes/namespace.yaml"      --ignore-not-found

echo "All Kubernetes resources deleted."
echo ""

read -rp "Also delete the Kind cluster '${CLUSTER_NAME}'? (y/N): " response
if [[ "${response}" =~ ^[Yy]$ ]]; then
  kind delete cluster --name "${CLUSTER_NAME}"
  echo "Kind cluster deleted."
else
  echo "Kind cluster kept."
fi
