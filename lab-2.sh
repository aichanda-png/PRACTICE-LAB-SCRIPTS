#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
FORCE_FLAG=0
[[ "${2:-}" == "--yes-i-know" ]] && FORCE_FLAG=1

NS_ING_OP="openshift-ingress-operator"
NS_ING="openshift-ingress"
IC_NAME="default"
ROUTER_SVC="router-default"

die(){ echo "ERROR: $*"; exit 1; }

need_oc(){
  command -v oc >/dev/null 2>&1 || die "oc CLI not found"
  oc whoami >/dev/null 2>&1 || die "oc not logged in"
}

ctx(){ oc config current-context 2>/dev/null || echo unknown; }

safety(){
  local c
  c="$(ctx | tr '[:upper:]' '[:lower:]')"
  for bad in prod production prd live; do
    if echo "$c" | grep -q "$bad"; then
      [[ $FORCE_FLAG -eq 1 ]] || die "Context '$c' looks prod-like. Pass --yes-i-know to override."
    fi
  done
}

inject(){
  need_oc
  safety

  oc -n "$NS_ING_OP" patch ingresscontroller "$IC_NAME" --type=merge -p \
    '{"spec":{"endpointPublishingStrategy":{"type":"LoadBalancerService","loadBalancer":{"scope":"Internal"}}}}'

  oc -n "$NS_ING" delete svc "$ROUTER_SVC" --ignore-not-found
}

case "${MODE}" in
  inject)  inject  ;;
  *) echo "Usage: $0 inject [--yes-i-know]"; exit 1 ;;
esac
