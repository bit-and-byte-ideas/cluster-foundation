# cluster-foundation

GitOps foundation for managing Kubernetes clusters. Provisions a local [kind](https://kind.sigs.k8s.io/) cluster, bootstraps [FluxCD](https://fluxcd.io/) as the cluster-level GitOps operator, and installs [ArgoCD](https://argo-cd.readthedocs.io/) via Flux for application deployments.

## Overview

This repository manages the lifecycle of Kubernetes clusters and their foundational infrastructure. It is structured to support multiple tenants and environments (`clusters/<tenant>/<env>`) so the same patterns extend naturally from local development to staging and production.

**Two GitOps layers, one clear boundary:**

| Layer | Tool | Owns |
|---|---|---|
| 1 — Cluster infrastructure | FluxCD | `GitRepository` CRDs, namespaces, ArgoCD installation, cluster-scope config |
| 2 — Application deployments | ArgoCD | `Application` CRs, kustomize overlays for user-facing services |

FluxCD bootstraps itself and installs ArgoCD. ArgoCD takes over for everything application-related. See [`CLAUDE.md`](./CLAUDE.md) for the full architecture decision record.

## Prerequisites

| Tool | Install |
|---|---|
| [kind](https://kind.sigs.k8s.io/) | `brew install kind` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | `brew install kubectl` |
| [flux CLI](https://fluxcd.io/flux/installation/) | `brew install fluxcd/tap/flux` |
| [Docker](https://www.docker.com/) | Docker Desktop or OrbStack |

You will also need a GitHub personal access token (PAT) with `repo` read/write permissions for `flux bootstrap`.

## Getting Started

```bash
# 1. Export your GitHub PAT
export GITHUB_TOKEN=<your-token>

# 2. Create the kind cluster, bootstrap FluxCD, and install ArgoCD
make cluster-up
```

`make cluster-up` runs three steps in sequence:
1. Creates a kind cluster (`local-dev`) using `kind/cluster-config.yaml`
2. Runs `flux bootstrap github` — Flux writes its components into `clusters/local/dev/flux-system/` and commits them to this repo
3. Flux reconciles `clusters/local/dev/infrastructure.yaml`, which installs ArgoCD via the kustomize overlay in `gitops/infrastructure/overlays/local/dev/`

Once the cluster is up (typically 2–4 minutes):

```bash
# Get the ArgoCD admin password
make argocd-password

# Open the ArgoCD UI at http://localhost:9080 (user: admin)
make argocd-port-forward
```

## Deploying Applications

Applications are deployed through ArgoCD, not through this repository. Create `Application` or `AppProject` resources in your application repositories and point them at this cluster (`https://kubernetes.default.svc`). All ArgoCD applications must use kustomize overlays.

## Makefile Reference

```
make cluster-up            Create cluster, bootstrap FluxCD and ArgoCD
make cluster-down          Destroy the kind cluster (prompts for confirmation)
make cluster-create        Create the kind cluster only
make cluster-delete        Destroy the kind cluster only
make flux-bootstrap        Bootstrap FluxCD (re-runnable, idempotent)
make flux-reconcile        Force reconcile flux-system immediately
make flux-reconcile-infra  Force reconcile infrastructure immediately
make argocd-password       Print the ArgoCD admin password
make argocd-port-forward   Port-forward ArgoCD UI to http://localhost:9080
make status                Show Flux and ArgoCD resource status
make kubeconfig            Print the kubeconfig for the kind cluster
```

## Clean Up

```bash
make cluster-down
```

You will be prompted to confirm before the cluster is destroyed. To skip the prompt:

```bash
CLUSTER_NAME=local-dev bash scripts/cluster-delete.sh --force
```

This removes the kind cluster and cleans up the kubectl context. The manifests committed to this repo by `flux bootstrap` (under `clusters/local/dev/flux-system/`) remain in git — delete them manually if you want a fully clean slate before re-bootstrapping.

## Repository Structure

```
cluster-foundation/
├── kind/
│   └── cluster-config.yaml              # kind cluster topology (1 control-plane, 1 worker)
├── scripts/
│   ├── lib/common.sh                    # Shared utilities and binary guards
│   ├── cluster-create.sh
│   ├── cluster-delete.sh
│   └── bootstrap-flux.sh
├── clusters/
│   └── local/dev/
│       ├── flux-system/                 # Written by flux bootstrap — do not edit manually
│       └── infrastructure.yaml          # Flux Kustomization CR pointing to the overlay below
└── gitops/infrastructure/
    ├── base/argocd/                     # Upstream ArgoCD install (version-pinned)
    └── overlays/local/dev/              # Local dev patches: insecure mode, single replicas
```

## Adding a New Cluster

1. Create `clusters/<tenant>/<env>/infrastructure.yaml` pointing at `gitops/infrastructure/overlays/<tenant>/<env>`
2. Create `gitops/infrastructure/overlays/<tenant>/<env>/kustomization.yaml` with environment-specific patches
3. Run `flux bootstrap github --path=clusters/<tenant>/<env>` against the target cluster
4. Commit and push — Flux reconciles the rest automatically

The base manifests in `gitops/infrastructure/base/` are reused without modification.

## Further Reading

- [`CLAUDE.md`](./CLAUDE.md) — Architecture decisions, GitOps layer responsibilities, and contributor guidance
- [FluxCD documentation](https://fluxcd.io/flux/)
- [ArgoCD documentation](https://argo-cd.readthedocs.io/)
