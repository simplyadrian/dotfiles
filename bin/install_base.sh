#!/bin/bash
set -e
set -o pipefail

PLATFORM=`uname`


doit() {
	if [[ $PLATFORM == 'Darwin' ]]; then
		install_mac_base
		install_dockerformac
		install_scripts
	elif [[ $PLATFORM == 'Linux' ]]; then
		export DEBIAN_FRONTEND=noninteractive
		get_user
		setup_sources
		install_linux_base
		install_scripts
		echo "run installer with configure_vim option without sudo to complete the setup"
	fi
}

# Choose a user account to use for this installation
get_user() {
    if [ -z "${TARGET_USER-}" ]; then
        PS3='Which user account should be used? '
        mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
        select opt in "${options[@]}"; do
            readonly TARGET_USER=$opt
            break
        done
    fi
}

# setup sudo for a user
# because fuck typing that shit all the time
# just have a decent password
# and lock your computer when you aren't using it
# if they have your password they can sudo anyways
# so its pointless
# i know what the fuck im doing ;)
setup_sudo() {
	# add user to sudoers
	adduser "$TARGET_USER" sudo

	# add user to systemd groups
	# then you wont need sudo to view logs and shit
	gpasswd -a "$TARGET_USER" systemd-journal
	gpasswd -a "$TARGET_USER" systemd-network

	# add go path to secure path
	{ \
		echo -e "Defaults	secure_path=\"/usr/local/go/bin:/home/${TARGET_USER}/.go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/bcc/tools:/home/${TARGET_USER}/.cargo/bin\""; \
		echo -e 'Defaults	env_keep += "ftp_proxy http_proxy https_proxy no_proxy GOPATH EDITOR"'; \
		echo -e "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"; \
		echo -e "${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"; \
	} >> /etc/sudoers

	# setup downloads folder as tmpfs
	# that way things are removed on reboot
	# i like things clean but you may not want this
	mkdir -p "/home/$TARGET_USER/Downloads"
	echo -e "\\n# tmpfs for downloads\\ntmpfs\\t/home/${TARGET_USER}/Downloads\\ttmpfs\\tnodev,nosuid,size=50G\\t0\\t0" >> /etc/fstab
}

install_mac_base_min() {
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

	# Check if Xcode is installed
	if      pkgutil --pkg-info com.apple.pkg.CLTools_Executables >/dev/null 2>&1
	then    printf '%s\n' "CHECKING INSTALLATION"
		count=0
		pkgutil --files com.apple.pkg.CLTools_Executables |
		while IFS= read file
		do
		test -e  "/${file}"         &&
		printf '%s\n' "/${file}…OK" ||
		{ printf '%s\n' "/${file}…MISSING"; ((count++)); }
		done
		if      (( count > 0 ))
		then    printf '%s\n' "Command Line Tools are not installed properly"
			# Provide instructions to remove and the CommandLineTools directory
			# and the package receipt then install instructions
		else    printf '%s\n' "Command Line Tools are installed"
		fi
	else   printf '%s\n' "Command Line Tools are not installed"
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
	fi
}

# install homebrew and packages
install_mac_base() {
	install_mac_base_min;
	(
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)";
	brew update && brew install \
		bash-completion \
		bc \
		bzip2 \
		cmake \
		curl \
		findutils \
		fortune \
		gcc \
		git \
		git-open \
		gnupg \
		gnupg2 \
		gnu-indent \
		grep \
		gzip \
		highlight \
		icdiff \
		jq \
		less \
		lsof \
		make \
		neovim \
		ngrep \
		nmap \
		openssl \
		python \
		tmux \
		tree \
		unzip;
	brew tap homebrew/cask-versions ;
	brew cask install --appdir="/Applications" \
		aws-vault \
		iterm2 \
		slack ;
	echo "Completed installing base packages via homebrew"
	)
}

# sets up apt sources
setup_sources() {
	cat <<-EOF > /etc/apt/sources.list
	deb-src http://archive.ubuntu.com/ubuntu focal main restricted
  deb http://us.archive.ubuntu.com/ubuntu/ focal main restricted
  deb-src http://us.archive.ubuntu.com/ubuntu/ focal universe main restricted multiverse
  deb http://us.archive.ubuntu.com/ubuntu/ focal-updates main restricted
  deb-src http://us.archive.ubuntu.com/ubuntu/ focal-updates universe main restricted multiverse
  deb http://us.archive.ubuntu.com/ubuntu/ focal universe
  deb http://us.archive.ubuntu.com/ubuntu/ focal-updates universe
  deb http://us.archive.ubuntu.com/ubuntu/ focal multiverse
  deb http://us.archive.ubuntu.com/ubuntu/ focal-updates multiverse
  deb http://us.archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
  deb-src http://us.archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
  deb http://archive.canonical.com/ubuntu focal partner
  deb-src http://archive.canonical.com/ubuntu focal partner
  deb http://security.ubuntu.com/ubuntu focal-security main restricted
  deb-src http://security.ubuntu.com/ubuntu focal-security universe main restricted multiverse
  deb http://security.ubuntu.com/ubuntu focal-security universe
  deb http://security.ubuntu.com/ubuntu focal-security multiverse
	EOF

	# turn off translations, speed up apt-get update
	mkdir -p /etc/apt/apt.conf.d
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations
}

# installs base packages
install_linux_base() {

	apt-get update
	apt-get -y upgrade

	apt-get install -y \
	    adduser \
	    apt-transport-https \
  		automake \
  		bash-completion \
  		bc \
  		bzip2 \
  		ca-certificates \
  		ca-certificates \
  		coreutils \
  		curl \
  		curl \
  		dirmngr \
  		dnsutils \
  		docker.io \
  		file \
  		findutils \
  		gcc \
  		git \
  		gnupg \
  		gnupg2 \
  		gnupg2 \
  		grep \
  		gzip \
  		hostname \
  		indent \
  		iptables \
  		jq \
  		less \
  		libc6-dev \
  		locales \
  		lsb-release \
  		lsof \
  		make \
  		mount \
  		net-tools \
  		policykit-1 \
  		rxvt \
  		silversearcher-ag \
  		ssh \
  		strace \
  		sudo \
  		tar \
  		tree \
  		tzdata \
  		unzip \
  		vim \
  		xclip \
  		xz-utils \
  		zip \
  		--no-install-recommends

	setup_sudo

	apt-get autoremove
	apt-get autoclean
	apt-get clean

}

# install rust

install_rust() {
	curl https://sh.rustup.rs -sSf | sh

	# Install rust-src for rust analyzer
	rustup component add rust-src
	# Install rust-analyzer
	curl -sSL "https://github.com/rust-analyzer/rust-analyzer/releases/download/2020-04-20/rust-analyzer-linux" -o "${HOME}/.cargo/bin/rust-analyzer"
	chmod +x "${HOME}/.cargo/bin/rust-analyzer"

	# Install clippy
	rustup component add clippy
}

# install docker for macosx
install_dockerformac() {
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
  	curl -sSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py  > /usr/local/bin/speedtest
  	chmod +x /usr/local/bin/speedtest

  	# install icdiff
  	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/icdiff > /usr/local/bin/icdiff
  	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/git-icdiff > /usr/local/bin/git-icdiff
  	chmod +x /usr/local/bin/icdiff
  	chmod +x /usr/local/bin/git-icdiff

  	# install lolcat
  	curl -sSL https://raw.githubusercontent.com/tehmaze/lolcat/master/lolcat > /usr/local/bin/lolcat
  	chmod +x /usr/local/bin/lolcat


  	local scripts=( have light )

  	for script in "${scripts[@]}"; do
  		curl -sSL "https://misc.j3ss.co/binaries/$script" > "/usr/local/bin/${script}"
  		chmod +x "/usr/local/bin/${script}"
  	done

    echo
    echo "Installing rust..."
    echo
    install_rust;
  }

install_vim() {
	# Install node, needed for coc.vim
	curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -

	# FROM: https://github.com/nodesource/distributions/blob/master/README.md
	# Replace with the branch of Node.js or io.js you want to install: node_6.x,
	# node_8.x, etc...
	VERSION=node_14.x
	# The below command will set this correctly, but if lsb_release isn't available, you can set it manually:
	# - For Debian distributions: jessie, sid, etc...
	# - For Ubuntu distributions: xenial, bionic, etc...
	# - For Debian or Ubuntu derived distributions your best option is to use
	# the codename corresponding to the upstream release your distribution is
	# based off. This is an advanced scenario and unsupported if your
	# distribution is not listed as supported per earlier in this README.
	DISTRO="$(lsb_release -s -c)"
	echo "deb https://deb.nodesource.com/$VERSION $DISTRO main" | sudo tee /etc/apt/sources.list.d/nodesource.list
	echo "deb-src https://deb.nodesource.com/$VERSION $DISTRO main" | sudo tee -a /etc/apt/sources.list.d/nodesource.list

	sudo apt update || true
	sudo apt install -y \
		nodejs \
		--no-install-recommends

	# create subshell
	(
	cd "$HOME"

	# install .vim files
	sudo rm -rf "${HOME}/.vim"
	git clone --recursive git@github.com:jessfraz/.vim.git "${HOME}/.vim"
	(
	cd "${HOME}/.vim"
	make install
	)

	# update alternatives to vim
	sudo update-alternatives --install /usr/bin/vi vi "$(command -v vim)" 60
	sudo update-alternatives --config vi
	sudo update-alternatives --install /usr/bin/editor editor "$(command -v vim)" 60
	sudo update-alternatives --config editor
	)
}

usage() {
	echo -e "install_base.sh\n\tThis script installs my basic packages for a Mac laptop\n"
	echo "Usage:"
	echo "doit			- install the base packages based on OS detection. including docker and custom scripts and neovim configuration"
	echo "install_vim		- install vim."
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "doit" ]]; then

		doit
	elif [[ $cmd == "install_vim" ]]; then

		install_vim
    else
		usage
	fi
}

main "$@"
