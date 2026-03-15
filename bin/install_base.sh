#!/bin/bash
set -e
set -o pipefail

# install.sh
#	This script installs my basic setup for a macOS or Ubuntu workstation.
#	Uses Rancher Desktop for container runtime (docker CLI) + Kubernetes.

PLATFORM=$(uname)
MACOS_MAJOR=0
export DEBIAN_FRONTEND=noninteractive

# Detect and display OS version
check_os() {
  if [[ $PLATFORM == 'Darwin' ]]; then
    local macos_version
    macos_version=$(sw_vers -productVersion)
    MACOS_MAJOR=$(echo "$macos_version" | cut -d. -f1)
    echo "Detected: macOS ${macos_version} ($(sw_vers -productName))"

    if (( MACOS_MAJOR < 11 )); then
      echo "ERROR: macOS 11 (Big Sur) or later is required. You have ${macos_version}."
      exit 1
    fi

    if (( MACOS_MAJOR < 12 )); then
      echo ""
      echo "⚠️  NOTE: macOS 11 (Big Sur) detected."
      echo "   Rancher Desktop requires macOS 12+. Docker + Colima will be installed instead."
      echo "   Kubernetes features (media stack k8s) will not be available on this machine."
      echo ""
    fi
  elif [[ $PLATFORM == 'Linux' ]]; then
    if command -v lsb_release &>/dev/null; then
      local distro
      distro=$(lsb_release -ds)
      local ubuntu_version
      ubuntu_version=$(lsb_release -rs)
      echo "Detected: ${distro}"

      # Check for Ubuntu 20.04+
      if [[ "$(lsb_release -is)" == "Ubuntu" ]]; then
        local ubuntu_major
        ubuntu_major=$(echo "$ubuntu_version" | cut -d. -f1)
        if (( ubuntu_major < 20 )); then
          echo "ERROR: Ubuntu 20.04 or later is required. You have ${ubuntu_version}."
          exit 1
        fi
      fi
    else
      echo "Detected: Linux ($(uname -r))"
    fi
  else
    echo "ERROR: Unsupported platform: ${PLATFORM}"
    exit 1
  fi
}

# Choose a user account to use for this installation
get_user() {
  if [[ -z "${TARGET_USER-}" ]]; then
    mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
    # if there is only one option just use that user
    if [ "${#options[@]}" -eq "1" ]; then
      readonly TARGET_USER="${options[0]}"
      echo "Using user account: ${TARGET_USER}"
      return
    fi

    # iterate through the user options and print them
    PS3='command -v user account should be used? '

    select opt in "${options[@]}"; do
      readonly TARGET_USER=$opt
      break
    done
  fi
}

doit() {
  check_os

  if [[ $PLATFORM == 'Darwin' ]]; then
    install_mac_base
    install_scripts
    configure_rancher_desktop
  elif [[ $PLATFORM == 'Linux' ]]; then
    export DEBIAN_FRONTEND=noninteractive
    get_user
    setup_sources
    install_linux_base
    install_scripts
    configure_rancher_desktop
    echo "run installer with install_vim option without sudo to complete the setup"
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
  {
    echo -e "Defaults	secure_path=\"/usr/local/go/bin:/home/${TARGET_USER}/.go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/bcc/tools:/home/${TARGET_USER}/.cargo/bin\""
    echo -e 'Defaults	env_keep += "ftp_proxy http_proxy https_proxy no_proxy GOPATH EDITOR"'
    echo -e "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"
    echo -e "${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"
  } >>/etc/sudoers

  # setup downloads folder as tmpfs
  # that way things are removed on reboot
  # i like things clean but you may not want this
  mkdir -p "/home/$TARGET_USER/Downloads"
  echo -e "\\n# tmpfs for downloads\\ntmpfs\\t/home/${TARGET_USER}/Downloads\\ttmpfs\\tnodev,nosuid,size=50G\\t0\\t0" >>/etc/fstab
}

install_mac_base_min() {
  # the utter bare minimal shit
  defaults write com.apple.finder AppleShowAllFiles YES           # show hidden files
  defaults write com.apple.dock tilesize -int 36                  # smaller icon sizes in Dock
  defaults write com.apple.dock autohide -bool true               # turn Dock auto-hidng on
  defaults write com.apple.dock autohide-delay -float 0           # remove Dock show delay
  defaults write com.apple.dock autohide-time-modifier -float 0   # remove Dock show delay
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true # show all file extensions
  killall Dock 2>/dev/null
  killall Finder 2>/dev/null
  echo "Setting Globals completed"

  # Check if Xcode is installed
  if pkgutil --pkg-info com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
    printf '%s\n' "CHECKING INSTALLATION"
    count=0
    pkgutil --files com.apple.pkg.CLTools_Executables |
      while IFS= read file; do
        test -e "/${file}" &&
          printf '%s\n' "/${file}…OK" ||
          {
            printf '%s\n' "/${file}…MISSING"
            ((count++))
          }
      done
    if ((count > 0)); then
      printf '%s\n' "Command Line Tools are not installed properly"
      # Provide instructions to remove and the CommandLineTools directory
      # and the package receipt then install instructions
    else
      printf '%s\n' "Command Line Tools are installed"
    fi
  else
    printf '%s\n' "Command Line Tools are not installed"
    # install Xcode Command Line Tools
    # https://github.com/timsutton/osx-vm-templates/blob/ce8df8a7468faa7c5312444ece1b977c1b2f77a4/scripts/xcode-cli-tools.sh
    sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    PROD=$(softwareupdate -l |
      grep "\*.*Command Line" |
      head -n 1 | awk -F"*" '{print $2}' |
      sed -e 's/^ *//' |
      tr -d '\n')
    softwareupdate -i "$PROD" --verbose
    echo "XCode has been installed/Updated."
  fi
}

# install homebrew and packages
install_mac_base() {
  install_mac_base_min
  (
    # Install Homebrew if not present
    if ! command -v brew &>/dev/null; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
    fi

    brew update && brew install \
      bash-completion \
      bash \
      bc \
      bzip2 \
      cmake \
      curl \
      findutils \
      fortune \
      gcc \
      git \
      git-open \
      gnu-indent \
      gnupg \
      gnupg2 \
      grep \
      gzip \
      helm \
      highlight \
      icdiff \
      jq \
      k9s \
      kubectl \
      less \
      lsof \
      make \
      ngrep \
      nmap \
      openssl \
      python@3 \
      tmux \
      tree \
      unzip \
      vim

    # Install container runtime
    if (( MACOS_MAJOR >= 12 )); then
      # macOS 12+ — Install Rancher Desktop (provides docker CLI + Kubernetes)
      if brew list --cask rancher &>/dev/null || [[ -d "/Applications/Rancher Desktop.app" ]]; then
        echo "Rancher Desktop already installed, upgrading..."
        brew upgrade --cask rancher 2>/dev/null || echo "Rancher Desktop is up to date."
      else
        brew install --cask rancher
      fi
    else
      # macOS 11 (Big Sur) — Rancher Desktop requires macOS 12+
      # Fall back to Docker CLI + Colima
      echo "Installing Docker CLI + Colima (Rancher Desktop requires macOS 12+)..."
      brew install docker docker-compose colima
    fi

    # Install iTerm2
    if brew list --cask iterm2 &>/dev/null || [[ -d "/Applications/iTerm.app" ]]; then
      echo "iTerm2 already installed, upgrading..."
      brew upgrade --cask iterm2 2>/dev/null || echo "iTerm2 is up to date."
    else
      brew install --cask iterm2
    fi
    echo "Completed installing base packages via homebrew"
  )
}

# sets up apt sources for modern Ubuntu
setup_sources() {
  local codename
  codename=$(lsb_release -cs)

  # turn off translations, speed up apt-get update
  mkdir -p /etc/apt/apt.conf.d
  echo 'Acquire::Languages "none";' >/etc/apt/apt.conf.d/99translations

  # Add Rancher Desktop repository
  curl -fsSL https://download.opensuse.org/repositories/isv:/Rancher:/stable/deb/Release.key \
    | gpg --dearmor | sudo tee /usr/share/keyrings/isv-rancher-stable-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/isv-rancher-stable-archive-keyring.gpg] https://download.opensuse.org/repositories/isv:/Rancher:/stable/deb/ ./" \
    | sudo tee /etc/apt/sources.list.d/isv-rancher-stable.list

  # Add kubectl repository (latest stable)
  local k8s_version
  k8s_version=$(curl -fsSL https://dl.k8s.io/release/stable.txt | sed 's/\.[0-9]*$//' | sed 's/v//')
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key" \
    | gpg --dearmor | sudo tee /usr/share/keyrings/kubernetes-apt-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list

  # Add helm repository
  curl -fsSL https://baltocdn.com/helm/signing.asc \
    | gpg --dearmor | sudo tee /usr/share/keyrings/helm-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/helm-archive-keyring.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
    | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
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
    coreutils \
    curl \
    dirmngr \
    dnsutils \
    file \
    findutils \
    gcc \
    git \
    gnupg \
    gnupg2 \
    grep \
    gzip \
    helm \
    hostname \
    indent \
    iptables \
    jq \
    kubectl \
    less \
    libc6-dev \
    locales \
    lsb-release \
    lsof \
    make \
    mount \
    net-tools \
    policykit-1 \
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
    software-properties-common \
    --no-install-recommends

  # Install Rancher Desktop (provides docker CLI + Kubernetes)
  if dpkg -l rancher-desktop &>/dev/null; then
    echo "Rancher Desktop already installed."
  else
    apt-get install -y rancher-desktop --no-install-recommends || {
      echo "WARNING: rancher-desktop package not found. Install manually from https://rancherdesktop.io"
    }
  fi

  setup_sudo

  apt-get autoremove -y
  apt-get autoclean
  apt-get clean
}

# install custom scripts/binaries
install_scripts() {
  # install speedtest
  curl -sSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py >/usr/local/bin/speedtest
  chmod +x /usr/local/bin/speedtest

  # install icdiff
  curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/icdiff >/usr/local/bin/icdiff
  curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/git-icdiff >/usr/local/bin/git-icdiff
  chmod +x /usr/local/bin/icdiff
  chmod +x /usr/local/bin/git-icdiff

  # install lolcat
  curl -sSL https://raw.githubusercontent.com/tehmaze/lolcat/master/lolcat >/usr/local/bin/lolcat
  chmod +x /usr/local/bin/lolcat
}

# configure container runtime post-install
configure_rancher_desktop() {
  echo "-----------------------------------------------"
  echo " Container Runtime Post-Install Configuration"
  echo "-----------------------------------------------"
  echo ""

  if [[ $PLATFORM == 'Darwin' ]] && (( MACOS_MAJOR < 12 )); then
    # macOS 11 — Colima path
    echo "Docker CLI + Colima have been installed (Rancher Desktop requires macOS 12+)."
    echo ""
    echo "To start Colima (Docker engine):"
    echo "  colima start"
    echo ""
    echo "To start with more resources:"
    echo "  colima start --cpu 4 --memory 8"
    echo ""
    echo "To verify:"
    echo "  docker ps"
    echo ""
    echo "⚠️  Kubernetes is NOT available with Colima on this machine."
    echo "   The media stack k8s manifests require Rancher Desktop (macOS 12+)."
    echo "   Docker containers (.dockerfunc) will work fine."
  else
    # macOS 12+ / Linux — Rancher Desktop path
    echo "Rancher Desktop has been installed. Please complete the following steps:"
    echo ""
    echo "1. Launch Rancher Desktop from your Applications menu."
    echo "2. On first launch, select the following settings:"
    echo "   - Container Engine: dockerd (moby) — this enables the 'docker' CLI"
    echo "   - Enable Kubernetes (select your desired version)"
    echo ""
    echo "Rancher Desktop places CLI tools (docker, kubectl, helm, nerdctl) in ~/.rd/bin"
    echo "This path has been added to your shell PATH via .path"
    echo ""

    # Ensure ~/.rd/bin exists for path setup
    mkdir -p "${HOME}/.rd/bin" 2>/dev/null || true

    if [[ $PLATFORM == 'Darwin' ]]; then
      echo "On macOS, Rancher Desktop also creates symlinks in /usr/local/bin."
      echo "If you previously had Docker Desktop or Colima, you may want to:"
      echo "  brew uninstall --cask docker 2>/dev/null"
      echo "  brew uninstall colima 2>/dev/null"
      echo "  brew uninstall docker 2>/dev/null"
    elif [[ $PLATFORM == 'Linux' ]]; then
      echo "On Linux, ensure your user is in the 'docker' group if socket access is needed:"
      echo "  sudo groupadd docker 2>/dev/null; sudo usermod -aG docker \$USER"
    fi
    echo ""
    echo "After launching Rancher Desktop and selecting dockerd (moby):"
    echo "  docker ps          # container management"
    echo "  kubectl get nodes  # kubernetes cluster"
    echo "  helm version       # helm charts"
  fi
  echo "-----------------------------------------------"
}

install_vim() {
  if [[ $PLATFORM == 'Linux' ]]; then
	  # Install Node.js (needed for coc.vim)
	  # Detect latest LTS major version dynamically
	  local node_major
	  node_major=$(curl -fsSL https://nodejs.org/dist/index.json \
	    | python3 -c "import json,sys; d=json.load(sys.stdin); print([x['version'] for x in d if x.get('lts')][0].split('.')[0].lstrip('v'))")
	  echo "Installing Node.js ${node_major}.x LTS..."

	  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
	    | gpg --dearmor | sudo tee /usr/share/keyrings/nodesource.gpg >/dev/null
	  echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${node_major}.x nodistro main" \
	    | sudo tee /etc/apt/sources.list.d/nodesource.list

	  sudo apt-get update || true
	  sudo apt-get install -y \
		nodejs \
		--no-install-recommends

	  # create subshell
	  (
		cd "$HOME"

		# install .vim files
		sudo rm -rf "${HOME}/.vim"
		git clone --recursive git@github.com-personal:simplyadrian/.vim.git "${HOME}/.vim"
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
  elif [[ $PLATFORM == 'Darwin' ]]; then
    (
      cd "$HOME"

      # install .vim files
      sudo rm -rf "${HOME}/.vim"
      git clone --recursive git@github.com-personal:simplyadrian/.vim.git "${HOME}/.vim"
      (
        cd "${HOME}/.vim"
        make install
      )
    )
  fi
}

usage() {
  echo -e "install_base.sh\n\tThis script installs my basic packages for a macOS or Ubuntu workstation\n"
  echo "Usage:"
  echo "  doit                - install base packages, Rancher Desktop, and custom scripts"
  echo "  install_vim         - install vim configuration"
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
