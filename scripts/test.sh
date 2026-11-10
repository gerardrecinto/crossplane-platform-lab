#!/usr/bin/env bash
# Creates a WebApp, checks what Crossplane builds, scales it, deletes it, checks cleanup.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok    $1 -> $2"; else echo "FAIL  $1 -> got '$2' want '$3'"; fail=1; fi; }
wait_for() { for _ in $(seq 1 60); do [ "$("${@:2}" 2>/dev/null)" = "$1" ] && return 0; sleep 2; done; return 1; }

kubectl apply -f examples/webapp.yaml >/dev/null
wait_for True kubectl -n apps get webapp hello -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
check "WebApp Ready"              "$(kubectl -n apps get webapp hello -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" True
check "Deployment replicas"       "$(kubectl -n apps get deploy hello -o jsonpath='{.spec.replicas}')" 2
check "Service port"              "$(kubectl -n apps get svc hello -o jsonpath='{.spec.ports[0].port}')" 80
wait_for 2 kubectl -n apps get webapp hello -o jsonpath='{.status.availableReplicas}'
check "status.availableReplicas"  "$(kubectl -n apps get webapp hello -o jsonpath='{.status.availableReplicas}')" 2

kubectl -n apps patch webapp hello --type merge -p '{"spec":{"replicas":3}}' >/dev/null
wait_for 3 kubectl -n apps get deploy hello -o jsonpath='{.spec.replicas}'
check "scaled to 3"               "$(kubectl -n apps get deploy hello -o jsonpath='{.spec.replicas}')" 3

echo "-- schema validation: replicas above the maximum is rejected"
if kubectl -n apps patch webapp hello --type merge -p '{"spec":{"replicas":9}}' >/dev/null 2>&1; then
  echo "FAIL  replicas 9 was accepted"; fail=1
else echo "ok    replicas 9 rejected"; fi

echo "-- drift: delete the Service, Crossplane puts it back"
kubectl -n apps delete svc hello >/dev/null
wait_for 80 kubectl -n apps get svc hello -o jsonpath='{.spec.ports[0].port}'
check "Service recreated"         "$(kubectl -n apps get svc hello -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)" 80

kubectl -n apps delete webapp hello --wait >/dev/null
wait_for "" kubectl -n apps get deploy hello -o name --ignore-not-found
check "Deployment cleaned up"     "$(kubectl -n apps get deploy hello -o name --ignore-not-found)" ""
exit $fail
