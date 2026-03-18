#!/usr/bin/env bash
# @file vars.sh
# @description Default HAProxy lifecycle variables for install/setup/hardening scripts.

export HAPROXY_SERVICE_NAME="${HAPROXY_SERVICE_NAME:-haproxy}"
export HAPROXY_CONFIG_PATH="${HAPROXY_CONFIG_PATH:-/etc/haproxy/haproxy.cfg}"
export HAPROXY_TEMPLATE_PATH="${HAPROXY_TEMPLATE_PATH:-overlays/base/scripts/ha-proxy/templates/haproxy.cfg.tpl}"
export HAPROXY_GLOBAL_BLOCK="${HAPROXY_GLOBAL_BLOCK:-$'global\n  log /dev/log local0\n  log /dev/log local1 notice\n  daemon\n  maxconn 2048\n  user haproxy\n  group haproxy\n  stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners'}"
export HAPROXY_DEFAULTS_BLOCK="${HAPROXY_DEFAULTS_BLOCK:-$'defaults\n  log global\n  mode tcp\n  option tcplog\n  option dontlognull\n  timeout connect 5s\n  timeout client 50s\n  timeout server 50s'}"
export HAPROXY_FRONTENDS_BLOCK="${HAPROXY_FRONTENDS_BLOCK:-$'frontend talos_k8s_api\n  bind *:6443\n  mode tcp\n  default_backend talos_k8s_api_backend'}"
export HAPROXY_BACKENDS_BLOCK="${HAPROXY_BACKENDS_BLOCK:-$'backend talos_k8s_api_backend\n  mode tcp\n  balance roundrobin\n  option tcp-check\n  server cp01 172.17.20.101:6443 check\n  server cp02 172.17.20.102:6443 check\n  server cp03 172.17.20.103:6443 check'}"
export HAPROXY_STATS_URI="${HAPROXY_STATS_URI:-/stats}"
export HAPROXY_STATS_USER="${HAPROXY_STATS_USER:-admin}"
export HAPROXY_STATS_PASS="${HAPROXY_STATS_PASS:-changeme}"
export HAPROXY_ALLOWED_PORTS="${HAPROXY_ALLOWED_PORTS:-6443,8404}"
export HAPROXY_SYSCTL_PROFILE="${HAPROXY_SYSCTL_PROFILE:-secure}"
