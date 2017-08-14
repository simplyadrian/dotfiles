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
}

# install homebrew and packages
install_brew() {
	(
	ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)";
	brew update && brew install \
		awscli \
		boost \
		bash-completion \
		bc \
		bzip2 \
		curl \
		findutils \
		fortune \
		gcc \
		git \
		gnupg \
		gnupg2 \
		gnu-indent \
		go \
		grep \
		gzip \
		icdiff \
		jq \
		less \
		lsof \
		make \
		neovim \
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

usage() {
	echo -e "install_base.sh\n\tThis script installs my basic packages for a Mac laptop\n"
	echo "Usage:"
	echo "base                      - install the base packages. including docker and custom scripts and neovim configuration"
	echo "install_docker            - install docker for macosx"
	echo "install_scripts           - install custom scripts and binaries from various sources"
	echo "configure_vim             - configure neovim."
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
    else
		usage
	fi
}

main "$@"
