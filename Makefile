.PHONY: all base bin dotfiles etc test shellcheck

PLATFORM := $(shell uname)

all: base bin dotfiles etc

base:
	# do install of all base packages
	$(CURDIR)/bin/install_base.sh doit

bin:
	# add aliases for things in bin
	for file in $(shell find $(CURDIR)/bin -type f -not -name "install-base.sh" -not -name ".*.swp"); do \
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

etc:
	# add config files on a Mac
	for file in $(shell find $(CURDIR)/etc -type f -not -name ".*.swp" -not path "X11" -not -path "apt"\
		-not -path "docker" -not -path "fonts" -not -name "slim.conf" -not -path "systemd" ); do \
		f=$$(echo $$file | sed -e 's|$(CURDIR)||'); \
		sudo mkdir -p $$f; \
		sudo ln -f $$file $$f; \
	done

else

dotfiles:
	# add symlinks for dotfiles on a Debian system
	for file in $(shell find $(CURDIR) -name ".*" -not -name ".gitignore" -not -name ".travis.yml" -not -name ".git" -not -name ".*.swp" ); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/$$f; \
	done; \
	ln -fn $(CURDIR)/gitignore $(HOME)/.gitignore;

etc:
	# add config files on a Debian System
	for file in $(shell find $(CURDIR)/etc -type f -not -name ".*.swp"); do \
		f=$$(echo $$file | sed -e 's|$(CURDIR)||'); \
		sudo mkdir -p $$f; \
		sudo ln -f $$file $$f; \
	done

endif

test: shellcheck

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

shellcheck:
	docker run --rm -i $(DOCKER_FLAGS) \
		--name df-shellcheck \
		-v $(CURDIR):/usr/src:ro \
		--workdir /usr/src \
		r.j3ss.co/shellcheck ./test.sh
