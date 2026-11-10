# crossplane-platform-lab

A self-service `WebApp` API built with Crossplane v2 on a local kind cluster. A developer writes six lines of YAML (image, port, replicas); Crossplane renders a Deployment and a Service, reports readiness back, puts deleted pieces back, and cleans up when the WebApp is deleted.

## Run it

Needs Docker, kind, kubectl and helm. About 3 minutes.

```
./scripts/up.sh      # kind cluster, Crossplane 2.4.3, the XRD, the Composition
./scripts/test.sh    # creates a WebApp and checks what happens
./scripts/down.sh
```

## What the test checks

| Step | Expected |
|---|---|
| apply `examples/webapp.yaml` | WebApp reaches Ready, Deployment has 2 replicas, Service on port 80 |
| status | `status.availableReplicas` is copied up from the Deployment |
| patch replicas to 3 | Deployment scales to 3 |
| patch replicas to 9 | rejected by the XRD schema (maximum is 5) |
| delete the Service by hand | Crossplane recreates it |
| delete the WebApp | Deployment is garbage collected |

## Files

- `platform/xrd.yaml`: the `WebApp` API (namespaced, Crossplane v2 style, no claims)
- `platform/composition.yaml`: a function pipeline using `function-go-templating`
- `platform/functions.yaml`: the function package
- `platform/rbac.yaml`: lets Crossplane manage Deployments and Services
- `examples/webapp.yaml`: what a developer applies

## Two things that cost me time

- **Ready stayed False.** I first used `function-auto-ready`. It never marked the Deployment or Service ready, so the WebApp sat at `Unready resources: deployment, service`. The Composition now sets readiness itself: the Deployment is ready when `availableReplicas` reaches the requested count, the Service once it exists.
- **Permissions.** In v2 Crossplane composes Deployments directly, and its service account cannot manage them by default. `platform/rbac.yaml` adds a ClusterRole with the aggregation label.

## Scope

Local kind cluster only, no cloud provider and no credentials. The same pattern applies to cloud resources through Crossplane providers, which this lab does not exercise.
