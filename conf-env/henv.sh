#!/bin/bash

set -ex

if ! dpkg -l | awk '{print $2}' | grep ^eatmydata &>/dev/null; then
	>&2 echo "Please, install 'eatmydata' package"
	exit 1
fi

markstr="# ---"
endstr="# --- Don't write after this"

usage()
{
cat << EOF
Usage: $(basename $0) [option]
My Home Environment Configuration

  [option]
  --gdbsimple           gdb simple configuration
  --gdbpro              gdb pro configuration
  --vim                 vim configuration with plugins
  --mc                  mc configuration
  --ftp                 ftp server configuration (vsftpd)
  --home                home cosmetic $HOME
  --bashrc              ~/.bashrc extra rules
  --env-packs           install usefull environment packages
  --xfce-hotkeys        xfce hotkeys configuration
  --xfce4-terminal      xfce4-terminal configuration
  --bash-completion     enable bash completion
  --locales             generate some locales
  --hosts               add local /etc/hosts
  --rm-rc               remove 'rc' packages
  --tmux                tmux configuration
  --sysctl              sysctl configuration
  -h, --help            show this help and exit

EOF

exit 0
}

msg_to_stdout()
{
	>&1 echo -e "\e[96m*** ----- $1 ----- ***\e[0m"
}

mark_msg_to_file()
{
	echo -e "$markstr" >> $1
}

end_msg_to_file()
{
	echo -e "\n$endstr" >> $1
}

# check mark and remove all lines after this (overwrite)
remove_lines_from_file()
{
	if grep "^$markstr" $1; then
		sed -i "/$markstr/Q" $1 # remove all lines
		sed -i '$ d' $1 # remove last empty line
	fi
}

install()
{
	packs=($@)
	sudo apt-get update

	set +e
	for p in ${packs[*]}; do
		if ! dpkg -l | awk '{print $2}' | grep ^$p$ &>/dev/null; then
			sudo eatmydata apt-get -y install $p
			echo -e "$?\n"
		fi
	done
	set -e
}

gdb_simple()
{
	msg_to_stdout "GDB simple configuration"
	install "gdb"

	if [ -e ~/.gdbinit ]; then
		remove_lines_from_file ~/.gdbinit
	fi

	mark_msg_to_file ~/.gdbinit
	echo >> ~/.gdbinit
	cat conf/gdbinit >> ~/.gdbinit
	end_msg_to_file ~/.gdbinit
}

gdb_pro()
{
	msg_to_stdout "GDB full configuration"
	install "gdb wget python-pip python3-pip"

	# download ready .gdbinit
	wget -P /tmp https://git.io/.gdbinit
	if [ $? == 0 ]; then
		cat /tmp/.gdbinit > ~/.gdbinit
		rm /tmp/.gdbinit
	fi

	pip install pygments --break-system-packages
	echo >> ~/.gdbinit
	gdb_simple
}

vim()
{
	msg_to_stdout "VIM configuration with plugins"
	install "vim vim-gtk3 ripgrep exuberant-ctags"

	plug_vim=~/.vim/autoload/plug.vim

	if [ ! -e $plug_vim ]; then
		curl -fLo $plug_vim --create-dirs \
		https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	fi

	cp conf/vimrc ~/.vimrc
	vim +PlugClean +PlugInstall +q +q
}

mc()
{
	msg_to_stdout "MC configuration"
	install "mc"

	mkdir -p ~/.config/mc
	sudo mkdir -p /root/.config/mc

	cp conf/{ini,panels.ini} ~/.config/mc
	sudo cp conf/{ini,panels.ini} /root/.config/mc
}

ftp()
{
	msg_to_stdout "FTP server configuration"
	install "vsftpd"

	# after vsftpd install have /srv/ftp
	if [ ! -d /srv/ftp/upload ]; then
		sudo mkdir /srv/ftp/upload
		sudo chmod 777 /srv/ftp/upload
	fi

	sudo cp conf/vsftpd.conf /etc/vsftpd.conf
	sudo systemctl restart vsftpd.service
}

home()
{
	msg_to_stdout "Home cosmetic $HOME"
	trash_dirs=(
		Видео Музыка Общедоступные Шаблоны Документы \
		Videos Music Public Templates Documents)

	for dir in ${trash_dirs[*]}; do
		[ -d ~/$dir ] && rm -ri ~/$dir
	done

	[ ! -d ~/sources ] && mkdir ~/sources
	ls ~
}

bashrc_append()
{
	echo >> ~/.bashrc
	cat conf/bashrc >> ~/.bashrc

	# my script directory '$HOME/main/bin'
	if mount | grep main &>/dev/null; then
		echo -e "\nexport PATH=$HOME/main/root/bin:\"\$${!PATH@}"\" >> ~/.bashrc
	fi

	if dpkg -l tmux &>/dev/null; then
		echo -e "\n[ -z \$TMUX ] && tmux" >> ~/.bashrc
	fi
}

bashrc()
{
	msg_to_stdout "~/.bashrc extra rules"
	remove_lines_from_file ~/.bashrc
	echo >> ~/.bashrc
	mark_msg_to_file ~/.bashrc
	bashrc_append
	end_msg_to_file ~/.bashrc
}

env_packs()
{
	msg_to_stdout "Install environment packages"
	list=(dnsutils traceroute whois tcpdump nmap curl wget ripgrep \
		netcat net-tools gcc make gdb nano vim vim-gtk3 mc strace xsel \
		moreutils coreutils bash-completion python-pip python3-pip \
		pkg-config valgrind automake autoconf binutils gpg dirmngr ca-certificates \
		locales sudo ssh sshpass info dpkg-dev devscripts lintian cdbs \
		debootstrap pbuilder eatmydata mousepad mawk gawk perl-base \
		man-db mandoc manpages manpages-dev manpages-posix \
		manpages-posix-dev linux-doc gcc-doc gcc-base-doc nfs-common \
		gparted patch fakeroot dh-make debhelper build-essential autotools-dev \
		psmisc dialog whiptail galculator exuberant-ctags hwinfo indent font-manager \
		xfonts-terminus tmux git wipe apt-file systemd-coredump)

	install "${list[*]}"

	sudo mandb
	sudo apt-file update
}

xfce_hotkeys()
{
	msg_to_stdout "XFCE hotkeys configuration"
	if ls /usr/bin/*-session | grep xfce4-session &>/dev/null; then
		install "gnome-screensaver"
		cp conf/xfce4-keyboard-shortcuts.xml \
		~/.config/xfce4/xfconf/xfce-perchannel-xml
	else
		>&2 echo "Current session not 'xfce4-session'"
		exit 1
	fi
}

xfce4_terminal()
{
	msg_to_stdout "XFCE4-TERMINAL configuration"
	if dpkg -l | awk '{print $2}' | grep ^xfce4-terminal &>/dev/null; then
		cp conf/terminalrc ~/.config/xfce4/terminal
	else
		>&2 echo "Please, install 'xfce4-terminal' package"
		exit 1
	fi
}

bash_completion()
{
	msg_to_stdout "Enable bash completion"
	install "bash-completion perl-base"
	if [ -e /etc/bash.bashrc ]; then
		sudo perl -i -pe '$i++ if /^#if ! shopt -oq posix;/; s/^#// if $i==1; $i=0 if /^fi/' \
		/etc/bash.bashrc
	else
		>&2 echo "/etc/bash.bashrc not exist"
		exit 1
	fi
}

locales()
{
	msg_to_stdout "Generate some locales"
	install "locales"
	for loc in en_US.UTF-8 ru_RU.UTF-8; do
		if ! grep ^$loc /etc/locale.gen &>/dev/null; then
			echo "$loc UTF-8" | sudo tee -a /etc/locale.gen
			sudo locale-gen
		fi
	done
}

hosts()
{
	msg_to_stdout "Add local /etc/hosts"
	sudo cp conf/hosts /etc/hosts
	sudo sed -i "s/<MY-HOSTNAME>/$(hostname)/" /etc/hosts &>/dev/null
}

rm_rc()
{
	msg_to_stdout "Remove 'rc' packages"
	rc_packs=$(dpkg -l | grep '^rc' | awk '{print $2}')
	for p in ${rc_packs[*]}; do
		sudo apt-get purge -y $p
	done
}

tmux()
{
	msg_to_stdout "TMUX configuration"
	install "tmux"
	cp conf/tmux.conf ~/.tmux.conf
}

sysctl()
{
	if [ ! -e /etc/sysctl.conf ]; then
		>&2 echo "/etc/sysctl.conf not exist"
		exit 1
	fi

sudo tee /etc/sysctl.conf << EOF
kernel.sysrq = 0
fs.suid_dumpable = 2
kernel.core_uses_pid = 1
kernel.core_pattern = /tmp/core-%e-%s-%u-%g-%p-%t
EOF

	sudo sysctl -p
	echo "Core file size: $(ulimit -c)"
}

while [ ! -z "$*" ]; do
	case "$1" in
		"--gdbsimple") gdb_simple ;;
		"--gdbpro") gdb_pro ;;
		"--vim") vim ;;
		"--mc") mc ;;
		"--ftp") ftp ;;
		"--home") home ;;
		"--bashrc") bashrc ;;
		"--env-packs") env_packs ;;
		"--xfce-hotkeys") xfce_hotkeys ;;
		"--xfce4-terminal") xfce4_terminal ;;
		"--bash-completion") bash_completion ;;
		"--locales") locales ;;
		"--hosts") hosts ;;
		"--rm-rc") rm_rc ;;
		"--tmux") tmux ;;
		"--sysctl") sysctl ;;
		"-h" | "--help") usage ;;
	esac
	shift
done
