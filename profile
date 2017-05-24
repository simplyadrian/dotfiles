# MacPorts Installer addition on 2015-05-26_at_10:35:51: adding an appropriate PATH variable for use with MacPorts.
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.

# Pyenv
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv virtualenvwrapper

# GO Stuff
export GOPATH=$HOME/golang
export GOROOT=/usr/local/opt/go/libexec
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin

SSH_ENV="$HOME/.ssh/environment"

function start_agent {
  echo "Initialising new SSH agent..."
  /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
  echo succeeded
  chmod 600 "${SSH_ENV}"
  . "${SSH_ENV}" > /dev/null
  /usr/bin/ssh-add;
}

# Source SSH settings, if applicable

if [ -f "${SSH_ENV}" ]; then
  . "${SSH_ENV}" > /dev/null
  #ps ${SSH_AGENT_PID} doesn't work under cywgin
  ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
  start_agent;
  }
else
  start_agent;
fi

# Shell prompt based on the Solarized Dark theme.
# Screenshot: http://i.imgur.com/EkEtphC.png
# Heavily inspired by @necolas’s prompt: https://github.com/necolas/dotfiles
# iTerm → Profiles → Text → use 13pt Monaco with 1.1 vertical spacing.
# vim: set filetype=sh :

if [[ $COLORTERM = gnome-* && $TERM = xterm ]] && infocmp gnome-256color >/dev/null 2>&1; then
	export TERM='gnome-256color';
elif infocmp xterm-256color >/dev/null 2>&1; then
	export TERM='xterm-256color';
fi;

prompt_git() {
	local s='';
	local branchName='';

	# Check if the current directory is in a Git repository.
	if [ $(git rev-parse --is-inside-work-tree &>/dev/null; echo "${?}") == '0' ]; then

		# check if the current directory is in .git before running git checks
		if [ "$(git rev-parse --is-inside-git-dir 2> /dev/null)" == 'false' ]; then

			# Ensure the index is up to date.
			git update-index --really-refresh -q &>/dev/null;

			# Check for uncommitted changes in the index.
			if ! $(git diff --quiet --ignore-submodules --cached); then
				s+='+';
			fi;

			# Check for unstaged changes.
			if ! $(git diff-files --quiet --ignore-submodules --); then
				s+='!';
			fi;

			# Check for untracked files.
			if [ -n "$(git ls-files --others --exclude-standard)" ]; then
				s+='?';
			fi;

			# Check for stashed files.
			if $(git rev-parse --verify refs/stash &>/dev/null); then
				s+='$';
			fi;

		fi;

		# Get the short symbolic ref.
		# If HEAD isn’t a symbolic ref, get the short SHA for the latest commit
		# Otherwise, just give up.
		branchName="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || \
			git rev-parse --short HEAD 2> /dev/null || \
			echo '(unknown)')";

		[ -n "${s}" ] && s=" [${s}]";

		echo -e "${1}${branchName}${blue}${s}";
	else
		return;
	fi;
}

if tput setaf 1 &> /dev/null; then
	tput sgr0; # reset colors
	bold=$(tput bold);
	reset=$(tput sgr0);
	# Solarized colors, taken from http://git.io/solarized-colors.
	black=$(tput setaf 0);
	blue=$(tput setaf 33);
	cyan=$(tput setaf 37);
	green=$(tput setaf 64);
	orange=$(tput setaf 166);
	purple=$(tput setaf 125);
	red=$(tput setaf 124);
	violet=$(tput setaf 61);
	white=$(tput setaf 15);
	yellow=$(tput setaf 136);
else
	bold='';
	reset="\e[0m";
	black="\e[1;30m";
	blue="\e[1;34m";
	cyan="\e[1;36m";
	green="\e[1;32m";
	orange="\e[1;33m";
	purple="\e[1;35m";
	red="\e[1;31m";
	violet="\e[1;35m";
	white="\e[1;37m";
	yellow="\e[1;33m";
fi;

# Highlight the user name when logged in as root.
if [[ "${USER}" == "root" ]]; then
	userStyle="${red}";
else
	userStyle="${blue}";
fi;

# Set the terminal title to the current working directory.
PS1="\[\033]0;\w\007\]";
PS1+="\[${bold}\] "; # space
PS1+="\[${userStyle}\]\u"; # username
PS1+="\[${white}\] in ";
PS1+="\[${green}\]\w"; # working directory
PS1+="\$(prompt_git \"${white} on ${violet}\")"; # Git repository details
PS1+="\n";
PS1+="\[${white}\]\$ \[${reset}\]"; # `$` (and reset color)
export PS1;

PS2="\[${yellow}\]→ \[${reset}\]";
export PS2;

set -o emacs
export HISTFILESIZE=
export HISTSIZE=
export HISTTIMEFORMAT="[%F %T] "
export PIP_DOWNLOAD_CACHE="$HOME/.pip/cache"
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad
export LS_COLORS='di=1:fi=0:ln=31:pi=5:so=5:bd=5:cd=5:or=31:mi=0:ex=35:*.rpm=90'
export EDITOR=vim
export PIP_EXTRA_INDEX_URL='https://pypi.python.org/simple/'
export AWS_DEFAULT_REGION=us-west-2
export GITHUB_TOKEN=
export SLACK_WEBHOOK_URL=
export IP=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')

#👀
alias xq_start='xhost + $IP'
alias dchrome='docker run -d --name chrome -e DISPLAY=$IP:0 --security-opt seccomp:/usr/local/etc/chrome.json -v /tmp/.X11-unix:/tmp/.X11-unix jess/chrome'
alias dci='docker-clean images'
alias dcc='docker-clean containers'
alias vim='mvim -v'
alias homebrew_fix_perms='sudo chown $(whoami):admin /usr/local && sudo chown -R $(whoami):admin /usr/local'
alias di='docker images'
alias dps='docker ps'
alias aws-vault-cleanup='sudo killall aws-vault && aws-vault rm -s bastion'
alias meta='sudo date;sudo aws-vault server &'
alias dev='export ENVIRONMENT=mgage_dev ENVIRONMENT_COLOR="0;32"; aws_shell'
alias stage='export ENVIRONMENT=mgage_staging ENVIRONMENT_COLOR="0;34"; aws_shell'
alias prod='export ENVIRONMENT=mgage_prod ENVIRONMENT_COLOR="0;31"; aws_shell'
alias global='export ENVIRONMENT=mgage_global ENVIRONMENT_COLOR="0;33"; aws_shell'
alias bosu='export ENVIRONMENT=mgage_bosu ENVIRONMENT_COLOR="0;37"; aws_shell'
alias build='export ENVIRONMENT=mgage_build ENVIRONMENT_COLOR="0;36"; aws_shell'

#modify prompt if environment is set
if [ -n "$ENVIRONMENT" ] ; then
  export PS1="[\e[${ENVIRONMENT_COLOR}m${ENVIRONMENT}\e[m]$PS1"
fi

#random helper functions
aws_shell () {
  aws-vault exec --session-ttl=4h --assume-role-ttl=60m "$ENVIRONMENT" --server -- bash -l
}

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
