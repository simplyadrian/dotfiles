#!/bin/bash
set -e
set -o pipefail

PLATFORM=`uname`


doit() {
	if [[ $PLATFORM == 'Darwin' ]]; then
		install_mac_base
		install_dockerformac
		install_scripts
		configure_vim
	elif [[ $PLATFORM == 'Linux' ]]; then
		export DEBIAN_FRONTEND=noninteractive
		get_user
		setup_sources
		install_linux_base
		install_scripts
		configure_vim
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

	# add ${TARGET_USER} to sudoers
	{ \
		echo -e "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"; \
		echo -e "${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"; \
	} >> /etc/sudoers

	declare file="/etc/fstab"
	declare regex="\s+\n# tmpfs for downloads\ntmpfs\t/home/${TARGET_USER}/Downloads\ttmpfs\tnodev,nosuid,size=2G\t0\t0\s+"

	declare file_content=$( cat "${file}" )
	if [[ " $file_content " =~ $regex ]] # please note the space before and after the file content
		then
			echo "found"
		else
			# setup downloads folder as tmpfs
			# that way things are removed on reboot
			# i like things clean but you may not want this
			mkdir -p "/home/$TARGET_USER/Downloads"
			echo -e "\n# tmpfs for downloads\ntmpfs\t/home/${TARGET_USER}/Downloads\ttmpfs\tnodev,nosuid,size=2G\t0\t0" >> /etc/fstab
		fi
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
		tmux \
		tree \
		unzip \
		cmake	\
		nmap \
		openssl \
		python;
	brew tap caskroom/versions ;
	brew cask install --appdir="/Applications" \
		aws-vault \
		iterm2 \
		slack ;
	echo "Completed installing base packages via homebrew"
	)
}

setup_sources_min() {
	apt-get update
	apt-get install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		lsb-release \
		gnupg2 \
		--no-install-recommends

	# hack for latest git (don't judge)
	cat <<-EOF > /etc/apt/sources.list.d/git-core.list
	deb http://ppa.launchpad.net/git-core/ppa/ubuntu xenial main
	deb-src http://ppa.launchpad.net/git-core/ppa/ubuntu xenial main
	EOF

	# neovim
	cat <<-EOF > /etc/apt/sources.list.d/neovim.list
	deb http://ppa.launchpad.net/neovim-ppa/unstable/ubuntu xenial main
	deb-src http://ppa.launchpad.net/neovim-ppa/unstable/ubuntu xenial main
	EOF

	# add the git-core ppa gpg key
	apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys E1DD270288B4E6030699E45FA1715D88E1DF1F24

	# add the neovim ppa gpg key
	apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 9DBB0BE9366964F134855E2255F96FCF8231B6DD

	# turn off translations, speed up apt-get update
	mkdir -p /etc/apt/apt.conf.d
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations
}

# sets up apt sources
# assumes you are going to use debian stretch
setup_sources() {
	setup_sources_min;

	cat <<-EOF > /etc/apt/sources.list
	deb http://httpredir.debian.org/debian stretch main contrib non-free
	deb-src http://httpredir.debian.org/debian/ stretch main contrib non-free

	deb http://httpredir.debian.org/debian/ stretch-updates main contrib non-free
	deb-src http://httpredir.debian.org/debian/ stretch-updates main contrib non-free

	deb http://security.debian.org/ stretch/updates main contrib non-free
	deb-src http://security.debian.org/ stretch/updates main contrib non-free

	deb http://httpredir.debian.org/debian/ jessie-backports main contrib non-free
	deb-src http://httpredir.debian.org/debian/ jessie-backports main contrib non-free

	deb http://httpredir.debian.org/debian experimental main contrib non-free
	deb-src http://httpredir.debian.org/debian experimental main contrib non-free

	EOF

	# add docker apt repo
	cat <<-EOF > /etc/apt/sources.list.d/docker.list
	deb https://apt.dockerproject.org/repo debian-stretch main
	deb https://apt.dockerproject.org/repo debian-stretch testing
	deb https://apt.dockerproject.org/repo debian-stretch experimental
	EOF

	# add docker gpg key
	apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

}

# installs base packages
install_linux_base() {

	apt-get update
	apt-get -y upgrade

	apt-get install -y \
		alsa-utils \
		apparmor \
		bridge-utils \
		cgroupfs-mount \
		libapparmor-dev \
		libltdl-dev \
		libseccomp-dev \
		network-manager \
		openvpn \
		adduser \
		automake \
		bash-completion \
		bc \
		bzip2 \
		ca-certificates \
		coreutils \
		curl \
		dnsutils \
		file \
		findutils \
		fortune \
		gcc \
		git \
		gnupg \
		gnupg2 \
		gnupg-agent \
		grep \
		gzip \
		hostname \
		indent \
		iptables \
		jq \
		less \
		libc6-dev \
		locales \
		lsof \
		make \
		mount \
		net-tools \
		neovim \
		pinentry-curses \
		silversearcher-ag \
		ssh \
		strace \
		sudo \
		tar \
		tree \
		tzdata \
		unzip \
		xclip \
		xcompmgr \
		xz-utils \
		zip \
		--no-install-recommends

	setup_sudo

	apt-get autoremove
	apt-get autoclean
	apt-get clean

}

# installs docker master
# and adds necessary items to boot params
install_docker() {
	# create docker group
	sudo groupadd docker
	sudo gpasswd -a "$TARGET_USER" docker

	# Include contributed completions
	mkdir -p /etc/bash_completion.d
	curl -sSL -o /etc/bash_completion.d/docker https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker


	# get the binary
	local tmp_tar=/tmp/docker.tgz
	local binary_uri="https://download.docker.com/linux/static/edge/x86_64"
	local docker_version
	docker_version=$(curl -sSL "https://api.github.com/repos/docker/docker-ce/releases/latest" | jq --raw-output .tag_name)
	docker_version=${docker_version#v}
	# local docker_sha256
	# docker_sha256=$(curl -sSL "${binary_uri}/docker-${docker_version}.tgz.sha256" | awk '{print $1}')
	(
	set -x
	curl -fSL "${binary_uri}/docker-${docker_version}.tgz" -o "${tmp_tar}"
	# echo "${docker_sha256} ${tmp_tar}" | sha256sum -c -
	tar -C /usr/local/bin --strip-components 1 -xzvf "${tmp_tar}"
	rm "${tmp_tar}"
	docker -v
	)
	chmod +x /usr/local/bin/docker*

	curl -sSL https://raw.githubusercontent.com/simplyadrian/dotfiles/master/etc/systemd/system/docker.service > /etc/systemd/system/docker.service
	curl -sSL https://raw.githubusercontent.com/simplyadrian/dotfiles/master/etc/systemd/system/docker.socket > /etc/systemd/system/docker.socket

	systemctl daemon-reload
	systemctl enable docker

	# update grub with docker configs and power-saving items
	sed -i.bak 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1 pcie_aspm=force apparmor=1 security=apparmor"/g' /etc/default/grub
	echo "Docker has been installed. If you want memory management & swap"
	echo "run update-grub & reboot"
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

	if [[ $PLATFORM == 'Darwin' ]]; then

		if [ -d "${HOME}/.vim" ]; then
			rm -rf "${HOME}/.vim"
			git clone https://github.com/simplyadrian/.vim.git "${HOME}/.vim"
			ln -snf "${HOME}/.vim/vimrc" "${HOME}/.vimrc"
		else
			# install .vim files
			git clone https://github.com/simplyadrian/.vim.git "${HOME}/.vim"
			ln -snf "${HOME}/.vim/vimrc" "${HOME}/.vimrc"
		fi
	elif [[ $PLATFORM == 'Linux' ]]; then
		if [ -d "${HOME}/.vim" ]; then
			rm -rf "${HOME}/.vim"
			git clone https://github.com/simplyadrian/.vim.git "${HOME}/.vim"
			ln -snf "${HOME}/.vim/vimrc" "${HOME}/.vimrc"
			sudo ln -snf "${HOME}/.vim" /root/.vim
			sudo ln -snf "${HOME}/.vimrc" /root/.vimrc
		else
			git clone https://github.com/simplyadrian/.vim.git "${HOME}/.vim"
			sudo ln -snf "${HOME}/.vim" /root/.vim
			sudo ln -snf "${HOME}/.vim" /root/.vimrc
		fi
		# alias vim dotfiles to neovim
		mkdir -p "${XDG_CONFIG_HOME:=$HOME/.config}"
		ln -snf "${HOME}/.vim" "${XDG_CONFIG_HOME}/nvim"
		ln -snf "${HOME}/.vimrc" "${XDG_CONFIG_HOME}/nvim/init.vim"
		# do the same for root
		sudo mkdir -p /root/.config
		sudo ln -snf "${HOME}/.vim" /root/.config/nvim
		sudo ln -snf "${HOME}/.vimrc" /root/.config/nvim/init.vim

		#update alternatives to neovim
		sudo update-alternatives --install /usr/bin/vi vi "$(which nvim)" 60
		sudo update-alternatives --config vi
		sudo update-alternatives --install /usr/bin/vim vim "$(which nvim)" 60
		sudo update-alternatives --config vim
		sudo update-alternatives --install /usr/bin/editor editor "$(which nvim)" 60
		sudo update-alternatives --config editor

		# install things needed for deoplete for vim
		sudo apt update

		sudo apt install -y \
			python3-pip \
			python3-setuptools \
			--no-install-recommends

		pip3 install -U \
			setuptools \
			wheel \
			neovim
	fi
	)
}

usage() {
	echo -e "install_base.sh\n\tThis script installs my basic packages for a Mac laptop\n"
	echo "Usage:"
	echo "doit			- install the base packages based on OS detection. including docker and custom scripts and neovim configuration"
	echo "configure_vim		- configure neovim."
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "doit" ]]; then

		doit
	elif [[ $cmd == "configure_vim" ]]; then

		configure_vim
    else
		usage
	fi
}

main "$@"
