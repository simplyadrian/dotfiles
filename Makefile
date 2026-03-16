.PHONY: all base bin dotfiles etc test test-quick test-yaml test-secrets shellcheck media

PLATFORM := $(shell uname)

all: base bin dotfiles etc

base:
	# do install of all base packages
	$(CURDIR)/bin/install_base.sh doit

bin:
	# add aliases for things in bin
	for file in $(shell find $(CURDIR)/bin -type f -not -name "install_base.sh" -not -name ".*.swp"); do \
		f=$$(basename $$file); \
		sudo ln -sf $$file /usr/local/bin/$$f; \
	done

ifeq ($(PLATFORM),Darwin)

dotfiles:
	# add symlinks for dotfiles on a Mac
	for file in $(shell find $(CURDIR) -name ".*" -not -name ".gitignore" -not -name ".travis.yml"\
		-not -name ".git" -not -name ".*.swp" -not -name ".xsessionsrc" -not -name ".Xresources"\
		-not -name ".Xprofile" -not -name ".Xdefaults" -not -path .fonts -not -path ".i3" -not -path ".urxvt"); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/$$f; \
	done; \
	ln -fn $(CURDIR)/gitignore $(HOME)/.gitignore;
else

dotfiles:
	# add symlinks for dotfiles on a Debian system
	for file in $(shell find $(CURDIR) -name ".*" -not -name ".gitignore" -not -name ".travis.yml" -not -name ".git" -not -name ".*.swp" ); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/$$f; \
	done; \
	ln -fn $(CURDIR)/gitignore $(HOME)/.gitignore;
endif

test: shellcheck

test-quick:
	# Fast tests: syntax + secrets + permissions (no shellcheck)
	./test.sh quick

test-yaml:
	# Validate k8s manifests
	./test.sh yaml

test-secrets:
	# Scan for leaked credentials
	./test.sh secrets

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

shellcheck:
	# Use local shellcheck if available, otherwise use docker (via Rancher Desktop)
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "Running shellcheck locally..."; \
		./test.sh; \
	else \
		echo "Running shellcheck via docker (Rancher Desktop)..."; \
		docker run --rm -i $(DOCKER_FLAGS) \
			--name df-shellcheck \
			-v $(CURDIR):/usr/src:ro \
			--workdir /usr/src \
			koalaman/shellcheck-alpine ./test.sh; \
	fi

###############################################################################
# Media Stack — create config dirs, download dirs & symlink tracked configs
# Usage: make media
###############################################################################
MEDIA_SERVICES := bazarr lazylibrarian overseerr prowlarr radarr sabnzbd sonarr transmission
MEDIA_CONFIG_DEST := $(HOME)/docker/configs
MEDIA_DOWNLOADS := $(HOME)/Torrents

media:
	# Create config directories for each media service
	@for svc in $(MEDIA_SERVICES); do \
		mkdir -p $(MEDIA_CONFIG_DEST)/$$svc; \
	done
	# Create download directories (shared by Transmission & SABnzbd)
	@mkdir -p $(MEDIA_DOWNLOADS)/complete $(MEDIA_DOWNLOADS)/incomplete
	# Symlink tracked config files into place
	@for src in $$(find $(CURDIR)/media/configs -type f); do \
		rel=$${src#$(CURDIR)/media/configs/}; \
		dest=$(MEDIA_CONFIG_DEST)/$$rel; \
		mkdir -p $$(dirname $$dest); \
		ln -sfn "$$src" "$$dest"; \
		echo "  linked $$rel"; \
	done
	@echo ""
	@echo "Config directories ready. Start the stack with:"
	@echo "  cd $(CURDIR)/media && docker compose up -d"

