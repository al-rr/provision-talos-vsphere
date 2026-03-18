__HAPROXY_GLOBAL_BLOCK__

__HAPROXY_DEFAULTS_BLOCK__

listen stats
  bind *:8404
  mode http
  stats enable
  stats uri __HAPROXY_STATS_URI__
  stats refresh 10s
  stats auth __HAPROXY_STATS_USER__:__HAPROXY_STATS_PASS__

__HAPROXY_FRONTENDS_BLOCK__

__HAPROXY_BACKENDS_BLOCK__
