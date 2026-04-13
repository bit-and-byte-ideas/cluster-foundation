# cluster-foundation Makefile
#
# Tenant/env is encoded in the cluster path. Override via environment variables.
# Example: TENANT=staging ENV=dev make cluster-up

CLUSTER_NAME  ?= local-dev
TENANT        ?= local
ENV           ?= dev
FLUX_NAMESPACE ?= flux-system

SCRIPTS_DIR   := scripts

.PHONY: help cluster-up cluster-down cluster-create cluster-delete \
        flux-bootstrap flux-reconcile argocd-password kubeconfig status

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} \
	/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

cluster-up: cluster-create flux-bootstrap ## Create cluster, bootstrap FluxCD and ArgoCD

cluster-down: cluster-delete ## Destroy the kind cluster

cluster-create: ## Create the kind cluster
	CLUSTER_NAME=$(CLUSTER_NAME) bash $(SCRIPTS_DIR)/cluster-create.sh

cluster-delete: ## Destroy the kind cluster (prompts for confirmation)
	CLUSTER_NAME=$(CLUSTER_NAME) bash $(SCRIPTS_DIR)/cluster-delete.sh

flux-bootstrap: ## Bootstrap FluxCD onto the cluster (requires GITHUB_TOKEN)
	CLUSTER_NAME=$(CLUSTER_NAME) TENANT=$(TENANT) ENV=$(ENV) \
		bash $(SCRIPTS_DIR)/bootstrap-flux.sh

flux-reconcile: ## Force Flux to reconcile flux-system immediately
	flux reconcile kustomization flux-system --with-source -n $(FLUX_NAMESPACE)

flux-reconcile-infra: ## Force Flux to reconcile infrastructure immediately
	flux reconcile kustomization infrastructure --with-source -n $(FLUX_NAMESPACE)

argocd-password: ## Print the initial ArgoCD admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d && echo

argocd-port-forward: ## Port-forward ArgoCD UI to localhost:9080
	kubectl port-forward svc/argocd-server -n argocd 9080:80

kubeconfig: ## Print the KUBECONFIG path for the kind cluster
	@kind get kubeconfig --name $(CLUSTER_NAME)

status: ## Show Flux and ArgoCD resource status
	@echo "\n=== Flux resources ==="
	flux get all -A
	@echo "\n=== ArgoCD applications ==="
	kubectl get applications -A 2>/dev/null || echo "ArgoCD not yet available"
