#!/usr/bin/env bash
set -euo pipefail
CROSSPLANE_VERSION="${CROSSPLANE_VERSION:-2.4.3}"
cd "$(dirname "$0")/.."

kind create cluster --name crossplane-lab
helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null
helm repo update crossplane-stable >/dev/null
helm upgrade --install crossplane crossplane-stable/crossplane --version "$CROSSPLANE_VERSION" \
  --namespace crossplane-system --create-namespace --wait --timeout 5m

kubectl apply -f platform/rbac.yaml
kubectl apply -f platform/functions.yaml
kubectl wait function.pkg --all --for=condition=Healthy --timeout=3m
kubectl apply -f platform/xrd.yaml
kubectl wait xrd/webapps.platform.example.org --for=condition=Established --timeout=2m
kubectl apply -f platform/composition.yaml
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
