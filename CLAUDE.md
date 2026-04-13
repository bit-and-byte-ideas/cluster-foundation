# cluster-foundation

This repository manages Kubernetes clusters using a GitOps model. It provisions clusters, bootstraps
FluxCD, and delegates application management to ArgoCD.

## Architecture Decision: FluxCD vs ArgoCD Responsibilities

**Decision date:** 2026-04-12

### Summary

This repository uses **two GitOps layers** with distinct, non-overlapping responsibilities:

| Layer   | Tool    | Manages                                                                 |
|---------|---------|-------------------------------------------------------------------------|
| Layer 1 | FluxCD  | Cluster-level infrastructure: `GitRepository` CRDs, `Kustomization` CRDs, namespaces, ArgoCD installation, and any other cluster-scope config |
| Layer 2 | ArgoCD  | Application deployments: `Application` CRs, `AppProject` CRs, app-level kustomize overlays |

### Rationale

**FluxCD** is the cluster bootstrapper. It is installed first (via `flux bootstrap`) and owns the
reconciliation loop that drives the cluster to its desired state. Its `GitRepository` CRD is the
canonical source reference. Everything FluxCD manages is cluster-scoped infrastructure — things
that must exist before any application can run.

**ArgoCD** is installed *by* FluxCD and has no awareness of FluxCD internals. It is purely an
application delivery platform. It provides a rich UI, diff visualization, AppProject RBAC, and
sync wave ordering that makes it better suited for multi-team application deployments than Flux
Kustomizations alone.

### Rule of thumb

> If it affects cluster infrastructure or enables application delivery → FluxCD owns it.
> If it deploys a user-facing application → ArgoCD owns it.

### What this means in practice

- **Never** create `Application` or `AppProject` CRs directly via FluxCD `Kustomization`s in
  `clusters/` — define them as ArgoCD resources in app repos or in an apps-of-apps pattern.
- **Never** use ArgoCD to install cluster-level controllers, CRDs, or namespaces — that belongs
  in `gitops/infrastructure/`.
- ArgoCD applications must use **kustomize** overlays (not Helm). Any Helm chart must be rendered
  via `kustomize build` with the Helm generator or managed via a FluxCD `HelmRelease` at the
  infrastructure layer.

---

## Repository Structure

```
cluster-foundation/
├── CLAUDE.md                        # This file — architecture decisions for collaborators
├── Makefile                         # Developer workflow entrypoints
├── .gitignore
├── kind/
│   └── cluster-config.yaml          # kind cluster topology
├── scripts/
│   ├── lib/common.sh                # Shared bash utilities and guards
│   ├── cluster-create.sh            # Create the kind cluster
│   ├── cluster-delete.sh            # Destroy the kind cluster
│   └── bootstrap-flux.sh            # Bootstrap FluxCD onto the cluster
├── clusters/
│   └── <tenant>/
│       └── <env>/                   # e.g. local/dev, staging/main, prod/us-east
│           ├── flux-system/         # Written by `flux bootstrap` — do not edit manually
│           └── infrastructure.yaml  # Flux Kustomization CR -> gitops/infrastructure/overlays/<tenant>/<env>
└── gitops/
    └── infrastructure/
        ├── base/                    # Tenant/env-agnostic base manifests
        │   └── argocd/
        └── overlays/
            └── <tenant>/
                └── <env>/           # Patches applied on top of base for this cluster
```

### Reconciliation chain

```
flux bootstrap --path=clusters/local/dev
  └── clusters/local/dev/flux-system/
        gotk-sync.yaml  (GitRepository "flux-system" + Kustomization "flux-system")
          └── clusters/local/dev/
                infrastructure.yaml  (Flux Kustomization CR)
                  └── gitops/infrastructure/overlays/local/dev/
                        kustomization.yaml  (plain kustomize)
                          └── gitops/infrastructure/base/argocd/
                                namespace.yaml          (Namespace argocd)
                                install.yaml            (upstream ArgoCD manifests)
                                argocd-cm-patch.yaml    (local dev settings)
                                  └── ArgoCD is now running
                                        └── ArgoCD reconciles Application CRs
                                              (defined in app repos, not here)
```

---

## Adding a New Cluster / Tenant / Environment

1. Create `clusters/<tenant>/<env>/infrastructure.yaml` — a Flux `Kustomization` CR pointing at
   `gitops/infrastructure/overlays/<tenant>/<env>`.
2. Create `gitops/infrastructure/overlays/<tenant>/<env>/kustomization.yaml` with any
   environment-specific patches (replica counts, TLS mode, resource limits).
3. Run `flux bootstrap github --path=clusters/<tenant>/<env>` against the target cluster.
4. Commit and push — Flux applies the infrastructure chain automatically.

Zero changes to `gitops/infrastructure/base/` are needed unless the base behavior itself changes.

---

## Prerequisites

| Tool       | Purpose                                  | Install                          |
|------------|------------------------------------------|----------------------------------|
| `kind`     | Local Kubernetes cluster                 | `brew install kind`              |
| `kubectl`  | Kubernetes CLI                           | `brew install kubectl`           |
| `flux`     | FluxCD CLI                               | `brew install fluxcd/tap/flux`   |
| `docker`   | Required by kind                         | Docker Desktop or OrbStack       |
| `make`     | Workflow entrypoints                     | Built into macOS                 |

---

## Quick Start

```bash
# 1. Set your GitHub token (required for flux bootstrap)
export GITHUB_TOKEN=<your-pat>

# 2. Create cluster and bootstrap FluxCD + ArgoCD
make cluster-up

# 3. Get ArgoCD admin password
make argocd-password

# 4. Tear everything down
make cluster-down
```

See `Makefile` for all available targets.
