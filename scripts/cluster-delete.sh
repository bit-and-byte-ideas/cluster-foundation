#!/usr/bin/env bash
# scripts/cluster-delete.sh — destroy the kind cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_binary kind kubectl

if ! cluster_exists; then
  log_warn "Cluster '${CLUSTER_NAME}' does not exist. Nothing to delete."
  exit 0
fi

# Confirmation prompt unless --force is passed
FORCE="${1:-}"
if [[ "${FORCE}" != "--force" ]]; then
  echo -e "${YELLOW}WARNING:${NC} This will permanently destroy cluster '${CLUSTER_NAME}'."
  read -r -p "Are you sure? [y/N] " confirm
  case "${confirm}" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_info "Aborted."
      exit 0
      ;;
  esac
fi

log_info "Deleting kind cluster '${CLUSTER_NAME}'..."
kind delete cluster --name "${CLUSTER_NAME}"

# Clean up the kubeconfig context if it still exists
if kubectl config get-contexts "kind-${CLUSTER_NAME}" &>/dev/null; then
  kubectl config delete-context "kind-${CLUSTER_NAME}" &>/dev/null || true
fi

log_ok "Cluster '${CLUSTER_NAME}' deleted."
