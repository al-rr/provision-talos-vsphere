! Managed by overlays/base/scripts/keepalived/setup.sh
global_defs {
  enable_script_security
  script_user root
}

vrrp_script __KEEPALIVED_TRACK_SCRIPT_NAME__ {
  script "__KEEPALIVED_TRACK_SCRIPT_COMMAND__"
  interval __KEEPALIVED_TRACK_SCRIPT_INTERVAL__
  weight __KEEPALIVED_TRACK_SCRIPT_WEIGHT__
}

vrrp_instance VI___KEEPALIVED_ROUTER_ID__ {
  state __KEEPALIVED_STATE__
  interface __KEEPALIVED_INTERFACE__
  virtual_router_id __KEEPALIVED_ROUTER_ID__
  priority __KEEPALIVED_PRIORITY__
  advert_int __KEEPALIVED_ADVERT_INT__

  authentication {
    auth_type __KEEPALIVED_AUTH_TYPE__
    auth_pass __KEEPALIVED_AUTH_PASS__
  }

__KEEPALIVED_UNICAST_BLOCK__

  virtual_ipaddress {
__KEEPALIVED_VIPS_BLOCK__
  }

__KEEPALIVED_TRACK_BLOCK__
}
