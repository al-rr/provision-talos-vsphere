.PHONY: lint-sh govc-plan govc-create govc-destroy haproxy-ha-run

lint-sh:
	bash ./overlays/base/scripts/lint-shell.sh --env=prod

GOVC_PROVISION_SCRIPT := ./overlays/base/scripts/ha-proxy/govc/provision.sh
GOVC_ENV ?= lab
GOVC_COUNT ?= 2
GOVC_PREFIX ?= talos-lb
GOVC_MODE ?= auto
GOVC_VARS_FILE ?=
GOVC_AUTO_FALLBACK_EMPTY ?= false
GOVC_VARS_ARG := $(if $(strip $(GOVC_VARS_FILE)),--vars-file=$(GOVC_VARS_FILE),)
GOVC_FALLBACK_ARG := $(if $(filter true,$(GOVC_AUTO_FALLBACK_EMPTY)),--auto-fallback-empty,--no-auto-fallback-empty)
HAPROXY_HA_SCRIPT := ./overlays/base/scripts/ha-proxy/run-full.sh
HAPROXY_HA_ENV ?= lab
HAPROXY_HA_COUNT ?= 2
HAPROXY_HA_PREFIX ?= talos-lb
HAPROXY_HA_MODE ?= auto
HAPROXY_HA_VARS_FILE ?=
HAPROXY_HA_OVERWRITE ?= false
HAPROXY_HA_SKIP_PROVISION ?= false
HAPROXY_HA_SKIP_HAPROXY ?= false
HAPROXY_HA_SKIP_KEEPALIVED ?= false
HAPROXY_HA_VARS_ARG := $(if $(strip $(HAPROXY_HA_VARS_FILE)),--vars-file=$(HAPROXY_HA_VARS_FILE),)
HAPROXY_HA_OVERWRITE_ARG := $(if $(filter true,$(HAPROXY_HA_OVERWRITE)),--overwrite,)
HAPROXY_HA_SKIP_PROVISION_ARG := $(if $(filter true,$(HAPROXY_HA_SKIP_PROVISION)),--skip-provision,)
HAPROXY_HA_SKIP_HAPROXY_ARG := $(if $(filter true,$(HAPROXY_HA_SKIP_HAPROXY)),--skip-haproxy,)
HAPROXY_HA_SKIP_KEEPALIVED_ARG := $(if $(filter true,$(HAPROXY_HA_SKIP_KEEPALIVED)),--skip-keepalived,)

govc-plan:
	$(GOVC_PROVISION_SCRIPT) --env=$(GOVC_ENV) $(GOVC_VARS_ARG) --count=$(GOVC_COUNT) --prefix=$(GOVC_PREFIX) --mode=$(GOVC_MODE) plan

govc-create:
	$(GOVC_PROVISION_SCRIPT) --env=$(GOVC_ENV) $(GOVC_VARS_ARG) --count=$(GOVC_COUNT) --prefix=$(GOVC_PREFIX) --mode=$(GOVC_MODE) $(GOVC_FALLBACK_ARG) create

govc-destroy:
	$(GOVC_PROVISION_SCRIPT) --env=$(GOVC_ENV) $(GOVC_VARS_ARG) --count=$(GOVC_COUNT) --prefix=$(GOVC_PREFIX) destroy

haproxy-ha-run:
	$(HAPROXY_HA_SCRIPT) --env=$(HAPROXY_HA_ENV) $(HAPROXY_HA_VARS_ARG) --count=$(HAPROXY_HA_COUNT) --prefix=$(HAPROXY_HA_PREFIX) --mode=$(HAPROXY_HA_MODE) $(HAPROXY_HA_OVERWRITE_ARG) $(HAPROXY_HA_SKIP_PROVISION_ARG) $(HAPROXY_HA_SKIP_HAPROXY_ARG) $(HAPROXY_HA_SKIP_KEEPALIVED_ARG)
