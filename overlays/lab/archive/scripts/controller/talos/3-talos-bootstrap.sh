#!/bin/bash

CLUSTER_NAME="k8s-cluster-lab"
TALOS_CONF_DIR="../talos/${CLUSTER_NAME}"
TALOSCONFIG_FILE="$TALOS_CONF_DIR/talosconfig"

if test -z "${CONTROL_PLANE_IP:-}"; then
    echo "Required variable CONTROL_PLANE_IP is not set"
    exit 1
fi

talosctl --talosconfig="$TALOSCONFIG_FILE" config endpoints "$CONTROL_PLANE_IP"
talosctl bootstrap --nodes "$CONTROL_PLANE_IP" --talosconfig="$TALOSCONFIG_FILE"
# talosctl bootstrap -n "$CONTROL_PLANE_IP" -e "$CONTROL_PLANE_IP" --talosconfig "$TALOSCONFIG_FILE"
# talosctl -n "$CONTROL_PLANE_IP" -e "$CONTROL_PLANE_IP" --talosconfig "$TALOSCONFIG_FILE" kubeconfig ~/.kube/kubeconfig
