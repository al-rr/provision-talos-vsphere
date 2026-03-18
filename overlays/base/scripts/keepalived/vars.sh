#!/usr/bin/env bash
# @file vars.sh
# @description Default Keepalived lifecycle variables for install/setup scripts.

export KEEPALIVED_SERVICE_NAME="keepalived"
export KEEPALIVED_CONFIG_PATH="/etc/keepalived/keepalived.conf"
export KEEPALIVED_TEMPLATE_PATH="overlays/base/scripts/keepalived/templates/keepalived.conf.tpl"
export KEEPALIVED_INTERFACE="auto"
export KEEPALIVED_ROUTER_ID="51"
export KEEPALIVED_STATE="BACKUP"
export KEEPALIVED_PRIORITY="100"
export KEEPALIVED_ADVERT_INT="1"
export KEEPALIVED_AUTH_TYPE="PASS"
export KEEPALIVED_AUTH_PASS="vrrp1234"
export KEEPALIVED_VIPS="172.17.20.90/24"
export KEEPALIVED_UNICAST_SRC_IP=""
export KEEPALIVED_UNICAST_PEERS="172.17.20.181,172.17.20.182"
export KEEPALIVED_TRACK_HAPROXY="true"
export KEEPALIVED_TRACK_SCRIPT_NAME="chk_haproxy"
export KEEPALIVED_TRACK_SCRIPT_COMMAND="systemctl is-active --quiet haproxy"
export KEEPALIVED_TRACK_SCRIPT_INTERVAL="2"
export KEEPALIVED_TRACK_SCRIPT_WEIGHT="-20"
