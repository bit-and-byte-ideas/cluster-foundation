#!/usr/bin/env bash
# scripts/bootstrap-flux.sh — bootstrap FluxCD onto the kind cluster
#
# Requires:
#   GITHUB_TOKEN  — GitHub personal access token with repo read/write permissions
#   GITHUB_OWNER  — GitHub user or organization that owns this repository
#   GITHUB_REPO   — Repository name (default: cluster-foundation)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_binary flux kubectl kind

# ── Configuration ──────────────────────────────────────────────────────────────
GITHUB_OWNER="${GITHUB_OWNER:-}"
GITHUB_REPO="${GITHUB_REPO:-cluster-foundation}"
FLUX_PATH="clusters/${TENANT}/${ENV}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  log_error "GITHUB_TOKEN is not set. Export a GitHub PAT with repo permissions."
  exit 1
fi

if [[ -z "${GITHUB_OWNER}" ]]; then
  # Try to infer from git remote
  GITHUB_OWNER="$(git -C "$(dirname "${SCRIPT_DIR}")" remote get-url origin 2>/dev/null \
    | sed -E 's|.*[:/]([^/]+)/[^/]+\.git.*|\1|' || true)"
  if [[ -z "${GITHUB_OWNER}" ]]; then
    log_error "GITHUB_OWNER is not set and could not be inferred from git remote."
    exit 1
  fi
  log_info "Inferred GITHUB_OWNER=${GITHUB_OWNER} from git remote."
fi

# ── Pre-flight ─────────────────────────────────────────────────────────────────
if ! cluster_exists; then
  log_error "Cluster '${CLUSTER_NAME}' does not exist. Run 'make cluster-create' first."
  exit 1
fi

kubectl config use-context "kind-${CLUSTER_NAME}"
ensure_cluster_reachable

log_info "Pre-flight: checking Flux prerequisites..."
flux check --pre

# ── Bootstrap ─────────────────────────────────────────────────────────────────
log_info "Bootstrapping FluxCD..."
log_info "  Owner : ${GITHUB_OWNER}"
log_info "  Repo  : ${GITHUB_REPO}"
log_info "  Path  : ${FLUX_PATH}"

flux bootstrap github \
  --owner="${GITHUB_OWNER}" \
  --repository="${GITHUB_REPO}" \
  --branch=main \
  --path="${FLUX_PATH}" \
  --personal \
  --namespace="${FLUX_NAMESPACE}"

# ── Wait for infrastructure ────────────────────────────────────────────────────
log_info "Waiting for 'infrastructure' Kustomization to become ready..."
flux wait kustomization infrastructure \
  --namespace="${FLUX_NAMESPACE}" \
  --timeout=10m || {
  log_warn "Infrastructure Kustomization did not become ready within timeout."
  log_warn "Check with: flux get kustomizations -A"
  log_warn "And:        kubectl get pods -n argocd"
}

log_ok "FluxCD bootstrapped successfully."
log_info "ArgoCD should be coming up in the 'argocd' namespace."
log_info "Run 'make argocd-password' to get the admin password."
log_info "Run 'make argocd-port-forward' to access the UI at http://localhost:8080."
