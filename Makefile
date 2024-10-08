## Traefik Makefile.
## Used with dcape at ../../
#:

SHELL               = /bin/bash
CFG                ?= .env

# Docker image version tested for actual dcape release
TRAEFIK_VER0       ?= 2.11.3

#- ******************************************************************************
#- Traefik: general config

#- Traefik external http port
TRAEFIK_LISTEN     ?= 80

#- Traefik external https port
TRAEFIK_LISTEN_SSL ?= 443
#- Let's encrypt user email
#- Value used only in `make apply` and saved in traefik.yml
TRAEFIK_ACME_EMAIL ?= admin@$(DCAPE_DOMAIN)

#- ------------------------------------------------------------------------------
#- Traefik: internal config

#- Docker image version
TRAEFIK_VER        ?= $(TRAEFIK_VER0)

#- Traefik hostname for internal access
#- This allows narra & drone internal access to local gitea without DNS
#- Used when host computer has no any ethernet interfaces
TRAEFIK_ALIAS      ?=

# Used in traefik.acme-step.yml only
# TODO: add TRAEFIK_CONFIG_TAG(s)
TRAEFIK_RESOLVER   ?= default
# StepCA URL, example: https://ca.dev.test/acme/acme/directory
TRAEFIK_CA_SERVER  ?=

APP_ROOT           ?= $(PWD)
#- dcape root directory
DCAPE_ROOT         ?= $(DCAPE_ROOT)
# ------------------------------------------------------------------------------

-include $(CFG)
export

ifdef DCAPE_STACK
include $(DCAPE_ROOT)/Makefile.dcape
else
include $(DCAPE_ROOT)/Makefile.app
endif

# ------------------------------------------------------------------------------

# TRAEFIK_CONFIG_TAG - Tag for apps/traefik/traefik.TAG.yml
# Values: local|acme-http|acme
# Used only in `make apply`
ifeq ($(ACME),no)
  TRAEFIK_CONFIG_TAG = local
else ifeq ($(ACME),yes)
  TRAEFIK_CONFIG_TAG = acme-http
  CONFIG_TRAEFIK += $(CONFIG_TRAEFIK_EMAIL)
else
  TRAEFIK_CONFIG_TAG = acme
  CONFIG_TRAEFIK += $(CONFIG_TRAEFIK_EMAIL)
endif
CONFIG_TRAEFIK += $(CONFIG_TRAEFIK_INTERNAL)
ifeq ($(DNS),no)
  PDNS_API_KEY = ***-see_powerdns_config-***
endif
ifeq ($(AUTH_TOKEN),)
  TRAEFIK_ALIAS ?= $(GITEA_HOST)
else
  TRAEFIK_ALIAS ?= $(DCAPE_HOST)
endif
export CONFIG_TRAEFIK

# ------------------------------------------------------------------------------

# check app version
init: $(DCAPE_VAR)/traefik/custom $(DCAPE_VAR)/traefik/traefik.env
	@if [[ "$$TRAEFIK_VER0" != "$$TRAEFIK_VER" ]] ; then \
	  echo "Warning: TRAEFIK_VER in dcape ($$TRAEFIK_VER0) differs from yours ($$TRAEFIK_VER)" ; \
	fi
	@echo "  Traefik tag: $(TRAEFIK_CONFIG_TAG)"
	@echo "  Dashboard URL: $(DCAPE_SCHEME)://$(DCAPE_HOST)/dashboard/"
	@echo "  HTTP port: $(TRAEFIK_LISTEN)"

# setup app
.setup-before-up: $(DCAPE_VAR)/traefik/traefik.yml $(DCAPE_VAR)/traefik/acme.json

# create config dir
$(DCAPE_VAR)/traefik/custom:
	@mkdir -p $@

$(DCAPE_VAR)/traefik/traefik.yml: $(APP_ROOT)/traefik.$(TRAEFIK_CONFIG_TAG).yml
	@sed -e "s/=DCAPE_TAG=/$$DCAPE_TAG/g" -e "s/=DCAPE_DOMAIN=/$$DCAPE_DOMAIN/g" \
	  -e "s/=TRAEFIK_RESOLVER=/$$TRAEFIK_RESOLVER/g" -e "s/=TRAEFIK_CA_SERVER=/$$TRAEFIK_CA_SERVER/g" \
	  -e "s/=TRAEFIK_EMAIL=/$$TRAEFIK_ACME_EMAIL/g" $<  > $@

$(DCAPE_VAR)/traefik/acme.json:
	@touch $@
	@chmod 600 $@

define ENV_TRAEFIK
# ENV data for traefik plugins (pdns etc)

# Sample for local powerdns:

##LEGO_EXPERIMENTAL_CNAME_SUPPORT=true
##PDNS_API_URL=http://ns:8081
##PDNS_API_KEY=$(DCAPE_PDNS_API_KEY)

# Own CA cert
# LEGO_CA_CERTIFICATES=/etc/traefik/root_ca.crt

endef
export ENV_TRAEFIK

$(DCAPE_VAR)/traefik/traefik.env:
ifeq ($(DNS),no)
	touch $@
else ifeq ($(DNS),yes)
	echo "$$ENV_TRAEFIK" > $@
else
	echo "$$ENV_TRAEFIK" | sed "s/##//g" > $@
endif
