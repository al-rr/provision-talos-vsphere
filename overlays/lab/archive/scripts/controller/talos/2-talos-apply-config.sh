#!/bin/bash

CLUSTER_NAME="k8s-cluster-lab"
TALOS_CONF_DIR="../talos/${CLUSTER_NAME}"
CONTROLPLANE_CONF_FILE="$TALOS_CONF_DIR/controlplane.yaml"
TALOSCONFIG_FILE="$TALOS_CONF_DIR/talosconfig"

if test -z "${CONTROL_PLANE_IP:-}"; then
    echo "Required variable CONTROL_PLANE_IP is not set"
    exit 1
fi

talosctl apply-config --nodes "$CONTROL_PLANE_IP" --insecure --file "$CONTROLPLANE_CONF_FILE"
