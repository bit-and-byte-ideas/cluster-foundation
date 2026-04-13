#!/usr/bin/env bash
# scripts/cluster-create.sh — create the kind cluster for local development

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
KIND_CONFIG="${REPO_ROOT}/kind/cluster-config.yaml"

require_binary kind kubectl docker

# Verify Docker is running
if ! docker info &>/dev/null; then
  log_error "Docker is not running. Start Docker and retry."
  exit 1
fi

if cluster_exists; then
  log_warn "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
  log_info "Run 'make cluster-delete' first if you want a fresh cluster."
  exit 0
fi

log_info "Creating kind cluster '${CLUSTER_NAME}' using config: ${KIND_CONFIG}"
kind create cluster \
  --name "${CLUSTER_NAME}" \
  --config "${KIND_CONFIG}" \
  --wait 120s

log_info "Switching kubectl context to kind-${CLUSTER_NAME}"
kubectl config use-context "kind-${CLUSTER_NAME}"

log_ok "Cluster '${CLUSTER_NAME}' is ready."
log_info "Next: run 'make flux-bootstrap' (requires GITHUB_TOKEN to be set)."
