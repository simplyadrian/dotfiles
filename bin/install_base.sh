#!/bin/bash
set -e

# install.sh
#	This script installs my basic setup for a Mac laptop

base() {
	# the utter bare minimal shit
	defaults write com.apple.finder AppleShowAllFiles YES; # show hidden files
	defaults write com.apple.dock tilesize -int 36; # smaller icon sizes in Dock
	defaults write com.apple.dock autohide -bool true; # turn Dock auto-hidng on
	defaults write com.apple.dock autohide-delay -float 0; # remove Dock show delay
	defaults write com.apple.dock autohide-time-modifier -float 0; # remove Dock show delay
	defaults write NSGlobalDomain AppleShowAllExtensions -bool true; # show all file extensions
	killall Dock 2>/dev/null;
	killall Finder 2>/dev/null;
	echo "Setting Globals completed"

	# install Xcode Command Line Tools
	# https://github.com/timsutton/osx-vm-templates/blob/ce8df8a7468faa7c5312444ece1b977c1b2f77a4/scripts/xcode-cli-tools.sh
	sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
	PROD=$(softwareupdate -l |
		grep "\*.*Command Line" |
		head -n 1 | awk -F"*" '{print $2}' |
		sed -e 's/^ *//' |
		tr -d '\n')
	softwareupdate -i "$PROD" --verbose;
	echo "XCode has been installed/Updated."

	install_brew
	install_docker
	install_scripts
	configure_vim
    install_golang
}

# install homebrew and packages
install_brew() {
	(
	ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)";
	brew update && brew install \
		bash-completion \
		bc \
		bzip2 \
		curl \
		findutils \
		fortune \
		gcc \
		git \
		git-open \
		gnupg \
		gnupg2 \
		gnu-indent \
		go \
		grep \
		gzip \
		highlight \
		icdiff \
		jq \
		less \
		lsof \
		make \
		macvim \
		ngrep \
		openvpn \
		s3cmd \
		tmux \
		tree \
		unzip \
		cmake	\
		nmap \
		openssl \
		python \
		tor ;
	brew tap caskroom/versions ;
	brew cask install --appdir="Applications" \
		google-chrome \
		iterm2 \
		java \
		xquartz \
		slack ;
	echo "Completed installing base packages via homebrew"
	)
}
# install docker for macosx
install_docker() {
	curl -o /tmp/Docker.dmg -sSL https://download.docker.com/mac/stable/Docker.dmg
	hdiutil attach /tmp/Docker.dmg
	sudo /bin/cp /Volumes/Docker/Docker.app/Contents/Library/LaunchServices/com.docker.vmnetd /Library/PrivilegedHelperTools
	sudo /bin/cp /Applications/Docker.app/Contents/Resources/com.docker.vmnetd.plist /Library/LaunchDaemons/
	sudo /bin/chmod 544 /Library/PrivilegedHelperTools/com.docker.vmnetd
	sudo /bin/chmod 644 /Library/LaunchDaemons/com.docker.vmnetd.plist
	sudo /bin/launchctl load /Library/LaunchDaemons/com.docker.vmnetd.plist
	hdiutil detach /Volumes/Docker
	echo "Docker has been installed."
}

# install custom scripts/binaries
install_scripts() {
	# install speedtest
	curl -sSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py  > /tmp/speedtest
	sudo cp /tmp/speedtest /usr/local/bin/speedtest
	sudo chmod +x /usr/local/bin/speedtest
	echo "The Speedtest binary has been installed"

	# install lolcat
	curl -sSL https://raw.githubusercontent.com/tehmaze/lolcat/master/lolcat > /tmp/lolcat
	sudo cp /tmp/lolcat /usr/local/bin/lolcat
	sudo chmod +x /usr/local/bin/lolcat
	echo "The lolcat binary has been installed"
}

# configure neovim with jessfraz's repo
configure_vim() {
	# create subshell
	(
	cd "$HOME"

	if [ -d "${HOME}/.vim" ]; then
		rm -rf "${HOME}/.vim"
		git clone --recursive git@github.com:simplyadrian/.vim.git "${HOME}/.vim"
		ln -snf "${HOME}/.vim/vimrc" "${HOME}/.vimrc"
	else
		# install .vim files
		git clone --recursive git@github.com:simplyadrian/.vim.git "${HOME}/.vim"
		ln -snf "${HOME}/.vim/vimrc" "${HOME}/.vimrc"
	fi
	)
}
# install/update golang from source
install_golang() {
	export GO_VERSION
	GO_VERSION=$(curl -sSL "https://golang.org/VERSION?m=text")
	export GO_SRC=/usr/local/go

	# if we are passing the version
	if [[ ! -z "$1" ]]; then
		GO_VERSION=$1
	fi

	# purge old src
	if [[ -d "$GO_SRC" ]]; then
		sudo rm -rf "$GO_SRC"
		sudo rm -rf "$GOPATH"
	fi

	GO_VERSION=${GO_VERSION#go}

	# subshell
	(
	curl -sSL "https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz" | sudo tar -v -C /usr/local -xz
	local user="$USER"
	# rebuild stdlib for faster builds
	sudo chown -R "${user}" /usr/local/go/pkg
	CGO_ENABLED=0 go install -a -installsuffix cgo std
	)

	# get commandline tools
	(
	set -x
	set +e
	go get github.com/golang/lint/golint
	go get golang.org/x/tools/cmd/cover
	go get golang.org/x/review/git-codereview
	go get golang.org/x/tools/cmd/goimports
	go get golang.org/x/tools/cmd/gorename
	go get golang.org/x/tools/cmd/guru

	go get github.com/jessfraz/apk-file
	go get github.com/jessfraz/audit
	go get github.com/jessfraz/certok
	go get github.com/jessfraz/cliaoke
	go get github.com/jessfraz/ghb0t
	go get github.com/jessfraz/junk/sembump
	go get github.com/jessfraz/netns
	go get github.com/jessfraz/pastebinit
	go get github.com/jessfraz/pepper
	go get github.com/jessfraz/reg
	go get github.com/jessfraz/udict
	go get github.com/jessfraz/weather

	go get github.com/axw/gocov/gocov
	go get github.com/crosbymichael/gistit
	go get github.com/davecheney/httpstat
	go get github.com/FiloSottile/gvt
	go get github.com/FiloSottile/vendorcheck
	go get github.com/google/gops
	go get github.com/jstemmer/gotags
	go get github.com/nsf/gocode
	go get github.com/rogpeppe/godef
	go get github.com/cbednarski/hostess/cmd/hostess

	# do special things for k8s GOPATH
	mkdir -p "${GOPATH}/src/k8s.io"
	kubes_repos=( community kubernetes release test-infra )
	for krepo in "${kubes_repos[@]}"; do
		git clone "https://github.com/kubernetes/${krepo}.git" "${GOPATH}/src/k8s.io/${krepo}"
		cd "${GOPATH}/src/k8s.io/${krepo}"
		git remote set-url --push origin no_push
		git remote add jessfraz "https://github.com/jessfraz/${krepo}.git"
	done
	)
}

usage() {
	echo -e "install_base.sh\n\tThis script installs my basic packages for a Mac laptop\n"
	echo "Usage:"
	echo "base                      - install the base packages. including docker and custom scripts and neovim configuration"
	echo "install_docker            - install docker for macosx"
	echo "install_scripts           - install custom scripts and binaries from various sources"
	echo "configure_vim             - configure neovim."
	echo "install_golang            - install golang from source"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "base" ]]; then

		base
	elif [[ $cmd == "install_docker" ]]; then

		install_docker
	elif [[ $cmd == "install_scripts" ]]; then

		install_scripts
	elif [[ $cmd == "configure_vim" ]]; then

		configure_vim
	elif [[ $cmd == "install_golang" ]]; then

		install_golang
    else
		usage
	fi
}

main "$@"
