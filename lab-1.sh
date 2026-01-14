#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"

NS="stresstest-cp"
DS="cp-memory-burner"

usage() {
  echo "Usage: $0 <start|stop|status|render>"
  exit 1
}

yaml_manifest() {
  cat <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: stresstest-cp
  labels:
    pod-security.kubernetes.io/enforce: privileged
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cp-memory-burner
  namespace: stresstest-cp
spec:
  selector:
    matchLabels:
      app: cp-memory-burner
  template:
    metadata:
      labels:
        app: cp-memory-burner
    spec:
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: burner
        image: docker.io/polinux/stress
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "15G", "--vm-keep", "--verbose"]
        resources:
          requests:
            memory: "16Gi"
            cpu: "1000m"
          limits:
            memory: "16Gi"
            cpu: "2000m"
      hostNetwork: false
      dnsPolicy: Default
YAML
}

if [[ -z "$MODE" ]]; then
  usage
fi

echo "Current oc context: $(oc config current-context 2>/dev/null || echo 'N/A')"

case "$MODE" in
  start)
    yaml_manifest | oc apply -f -
    ;;

  stop)
    yaml_manifest | oc delete -f - --ignore-not-found
    ;;

  render)
    # prints the manifest (useful for review / piping elsewhere)
    yaml_manifest
    ;;

  *)
    echo "Unknown mode: $MODE"
    usage
    ;;
esac
