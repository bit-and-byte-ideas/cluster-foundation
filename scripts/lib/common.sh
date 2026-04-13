#!/usr/bin/env bash
# scripts/lib/common.sh — shared utilities for cluster management scripts

set -euo pipefail

# Defaults (can be overridden via environment)
CLUSTER_NAME="${CLUSTER_NAME:-local-dev}"
TENANT="${TENANT:-local}"
ENV="${ENV:-dev}"
FLUX_NAMESPACE="${FLUX_NAMESPACE:-flux-system}"

# ── Logging ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # no color

log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Dependency guard ───────────────────────────────────────────────────────────
require_binary() {
  for bin in "$@"; do
    if ! command -v "$bin" &>/dev/null; then
      log_error "Required binary not found: $bin"
      log_error "Install it and re-run this script."
      exit 1
    fi
  done
}

# ── Cluster helpers ────────────────────────────────────────────────────────────
cluster_exists() {
  kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"
}

ensure_cluster_reachable() {
  if ! kubectl cluster-info --context "kind-${CLUSTER_NAME}" &>/dev/null; then
    log_error "Cluster kind-${CLUSTER_NAME} is not reachable. Is it running?"
    exit 1
  fi
}

export_kubeconfig() {
  export KUBECONFIG
  KUBECONFIG="$(kind get kubeconfig --name "${CLUSTER_NAME}" 2>/dev/null | grep -o 'KUBECONFIG=.*' | cut -d= -f2 || true)"
  # Fallback: use kubectl context switching
  kubectl config use-context "kind-${CLUSTER_NAME}" &>/dev/null || true
}
