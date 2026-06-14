---
name: gitops-tenant-onboarding
description: >-
  Onboard a new tenant application onto a Flux-based GitOps platform: scaffold
  the tenant repo's deploy manifests, wire OpenBao/Vault secrets via External
  Secrets, fit the cluster's Kyverno/PodSecurity and default-deny network
  policies, expose the app through a shared Gateway API gateway, and register
  the tenant on the platform with signed-OCI Flux resources. Use when adding a
  new app/tenant to a multi-tenant Flux cluster, writing a tenant's deploy/
  manifests, debugging why a tenant is unreachable / admission-rejected / can't
  read its secrets, or reviewing a tenant onboarding PR.
license: Apache-2.0
---

# GitOps Tenant Onboarding

Onboarding a **tenant** — an application that runs on a shared, multi-tenant
[Flux](https://fluxcd.io/) cluster from its **own repository** — follows the same
recurring shape every time. The tenant repo builds a container image and publishes
its Kubernetes manifests as a **signed OCI artifact**; the platform pulls that
artifact with a Flux `OCIRepository` + `Kustomization` and runs it in a dedicated,
locked-down namespace. This skill is the agent-facing companion to that pattern:
the decisions, the conventions, and — most usefully — the **gotchas that make a
fresh tenant fail** if you miss them.

It is built around an opinionated but industry-standard stack — Flux, [External
Secrets Operator](https://external-secrets.io/) backed by OpenBao/Vault,
[Kyverno](https://kyverno.io/) + PodSecurity, Cilium / [Gateway
API](https://gateway-api.sigs.k8s.io/), [cosign](https://www.sigstore.dev/) — so
the steps transfer to any cluster wired the same way; adapt the resource names to
your platform.

## The two halves

Onboarding always spans **two repos**, and a tenant is not live until both land:

1. **The tenant repo** — created from a tenant template. Ships the shared,
   framework-agnostic CI/CD plumbing (build → signed publish → release) plus a
   `deploy/` directory of Kubernetes manifests you own and customise.
2. **The platform registration** — a small directory in the platform repo
   (`apps/<tenant>/`) that grants the tenant a namespace, an identity (a
   ServiceAccount), RBAC, a network policy, the OpenBao-backed image-pull secret,
   and the Flux resources that pull and verify the tenant's artifact.

Open each as a PR. The tenant goes live when the **platform registration** merges
and Flux reconciles it — the tenant repo alone does nothing until it is registered.

## Tenant repo: the `deploy/` manifests

A tenant's `deploy/` is a Kustomize overlay. The full set, and what each is *for*:

| Manifest | Purpose | Drop it when… |
|---|---|---|
| `deployment.yaml` | the workload | — |
| `service.yaml` | ClusterIP for the app port | — |
| `httproute.yaml` | Gateway API `HTTPRoute` attaching to the shared gateway | the app is not HTTP-exposed |
| `poddisruptionbudget.yaml` | drain-safe `maxUnavailable: 1` PDB | never — every workload needs one |
| `networkpolicy.yaml` | re-opens ingress/egress under the cluster's default-deny | never on a default-deny cluster |
| `secretstore.yaml` + `externalsecret.yaml` | namespaced External Secrets store + secret | the tenant needs no app secrets |
| `cluster.yaml` | CloudNativePG database | the tenant has no database |
| `kustomization.yaml` | lists the above | — |

### Conventions and gotchas that bite

These are the failure modes worth memorising — each one produces a tenant that
*looks* configured but is broken at reconcile, admission, or runtime:

- **The container `name` MUST equal the repository name.** The signed-publish
  pipeline pins the freshly built image digest into the container named after the
  repo. A mismatch means the running image is never updated. Rename the
  placeholder container throughout `deployment.yaml`.
- **Set the `seccompProfile` at the *pod* level, not only the container.** A
  PodSecurity "restricted" cluster (and a Kyverno `require-seccomp-profile` rule)
  demands `securityContext.seccompProfile.type: RuntimeDefault` on the **pod
  spec**. Setting it only on the container passes naive review but is rejected at
  admission. Set `runAsNonRoot: true` + `seccompProfile` on both pod and
  container; the container also gets `allowPrivilegeEscalation: false`,
  `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`.
- **A default-deny cluster makes a tenant unreachable until it ships an allow
  policy.** If the platform generates a deny-all network policy in every tenant
  namespace, a tenant with no `networkpolicy.yaml` cannot receive Gateway traffic
  or reach its own database. Ship the allow policy day-one: ingress from the
  gateway on the app port, egress to DNS, plus intra-namespace + operator rules if
  it has a database. (With Cilium, an empty endpoint selector `{}` in a
  `fromEndpoints`/`toEndpoints` rule selects this namespace's own pods — so
  intra-namespace rules need no namespace name and stay placeholder-free.)
- **Tenant secrets come from the secret store, never SOPS.** No tenant ships an
  encrypted Secret in git. App secrets are delivered by External Secrets from
  OpenBao/Vault (see below). The Flux `Kustomization` needs **no** `spec.decryption`.
- **Use a *namespaced* `SecretStore`, never the shared `ClusterSecretStore`.** A
  multi-tenant cluster blocks tenants from referencing the cluster-scoped store (a
  Kyverno `restrict-tenant-secret-stores`-style policy) so one tenant can't read
  another's path. The namespaced store authenticates via the tenant's own Vault
  role, scoped to `apps/<tenant>/*`. The single carve-out is the platform-managed
  image-pull secret (below), applied by the GitOps controller, not the tenant.
- **`maxUnavailable: 1`, not `minAvailable: 1`, in the PDB.** `maxUnavailable: 1`
  is drain-safe at *every* replica count — at one replica the pod can still be
  evicted (no deadlock), at 2+ it gives rolling protection. A `minAvailable: 1`
  PDB over a single replica permits **zero** voluntary evictions and wedges every
  node drain (autoscaler recycles, rolling reboots).
- **If you start under the HA replica floor, opt out explicitly.** A cluster that
  audits for a minimum replica count (e.g. 3) will flag a fresh single-replica
  tenant. Carry the platform's exemption label day-one to stay clean in policy
  reports; delete it and raise `replicas` when you want HA.
- **The `HTTPRoute` attaches to the *shared* gateway** via `parentRefs`
  (`name`/`namespace`/`sectionName`), not a per-tenant gateway. Set the
  `hostnames` to the tenant's real host and the `backendRefs` to the tenant
  Service.

## Secrets: app secrets vs. the image-pull secret

Two different mechanisms, often confused:

- **App secrets** (DB creds, API keys) — *tenant-owned end-to-end*. The platform
  provisions only the namespaced `SecretStore` + the Vault role/policy (scoped to
  `apps/<tenant>/*`, read **and** write so the tenant can seed); it never seeds a
  tenant's app values. How a value reaches the path is the tenant's business:
  paste an externally-issued credential straight into OpenBao, or seed a generated
  value in-cluster with a `Password` generator → `PushSecret` (`refreshInterval:
  "0"`) → `ExternalSecret`. The only hard rules: nothing sensitive sits in git in
  plaintext, and workloads read values **from the store via `ExternalSecret`s**.
- **The image-pull secret** (`ghcr-auth` / equivalent) — *platform-managed*, not a
  tenant secret. The registration dir ships an `ExternalSecret` that sources the
  shared registry pull credential from the **cluster-scoped** store and
  materialises the dockerconfigjson the `OCIRepository` and ServiceAccount consume.
  It may use the ClusterSecretStore precisely because the GitOps controller (not
  the tenant SA) applies it — the policy carves out controller-applied resources.

## Platform registration: `apps/<tenant>/`

Copy an existing tenant directory and rename. The resource set:

| File | Purpose |
|---|---|
| `namespace.yaml` | namespace with `pod-security.kubernetes.io/enforce: restricted` |
| `serviceaccount.yaml` | SA, `automountServiceAccountToken: false`, `imagePullSecrets: [ghcr-auth]` |
| `rolebinding.yaml` | binds the SA to the `edit` ClusterRole in the namespace |
| `networkpolicy.yaml` | platform-side ingress/egress for the tenant |
| `ghcr-auth-externalsecret.yaml` | image-pull secret from the cluster-scoped store |
| `secretstore.yaml` | *only if the tenant needs app secrets* — namespaced store via the tenant Vault role |
| `sync.yaml` | `OCIRepository` (semver range, cosign `verify`) + `Kustomization` (`prune: true`, `serviceAccountName: <tenant>`) |

Then add `<tenant>/` to the apps `kustomization.yaml`. For a tenant that runs its
**own** external-dns for a custom domain, add the extra grants (an
`external-dns-rbac.yaml` binding the tenant external-dns SA to the tenant-scoped
ClusterRoles, and an FQDN-pinned `external-dns-networkpolicy.yaml`) — mirror a
tenant that already does this rather than inventing the RBAC.

In `sync.yaml`, set the artifact `url` (`oci://<registry>/<tenant>/manifests`) and
keep the `verify` block pointed at the trusted publish-workflow identity, so only
artifacts produced by that workflow are ever reconciled.

## Publishing & trust

On every release tag, the tenant's CD calls the platform's signed-publish
workflow: it builds and pushes the image, **pins the digest** into
`deployment.yaml`, pushes the manifests as an OCI artifact, and **cosign-signs**
both (keyless, via CI OIDC). The platform's `OCIRepository` verifies that
signature against the publish-workflow identity — the trust root that ensures only
artifacts from the trusted pipeline reach the cluster. Tags come from
Conventional-Commit merges to `main` driving semantic-release, so a normal merge
produces a publish automatically.

## Validate before you open the PR

- **Render + schema-validate** the tenant `deploy/` and the platform registration:
  `kubectl kustomize <dir> | kubeconform -strict` (with built-in schemas + a pinned
  CRD catalog for the operators in use). This catches a broken or schema-invalid
  manifest before CI.
- **Walk the gotcha list above** against the diff — container-name == repo-name,
  pod-level seccomp, an allow network policy present, namespaced (not cluster)
  SecretStore, `maxUnavailable` PDB, replica-floor handled, `HTTPRoute` parent +
  hostname set.
- **Confirm both halves exist** — a tenant repo with no platform registration (or
  vice versa) is a half-onboarded tenant that will never reconcile.

## Staying current

The tenant template keeps the shared plumbing current via template-sync: it opens
a PR in the tenant whenever a pinned action, a workflow, or a convention changes.
Review and merge it like any dependency update — the files the tenant owns
(`deploy/`, app code, CI) are listed in `.templatesyncignore` and never touched.
