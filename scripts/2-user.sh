#!/usr/bin/env bash

echo "
-------------------------------------------------------------------------
  ██╗  ██╗ ██████╗ ██████╗ ████████╗██████╗██╗  ██╗     ██████╗ ███████╗
  ██║  ██║██╔═══██╗██╔══██╗╚══██╔══╝██╔═══ ╚██╗██╔╝    ██╔═══██╗██╔════╝
  ██║  ██║██║   ██║██████╔╝   ██║   ████╗   ╚███╔╝ ███╗██║   ██║███████╗
  ╚██╗██╔╝██║   ██║██╔══██╗   ██║   ██╔═╝   ██╔██╗ ╚══╝██║   ██║╚════██║
   ╚███╔╝ ╚██████╔╝██║  ██║   ██║   ██████╗██╔╝╚██╗    ╚██████╔╝███████║
    ╚══╝   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═════╝╚═╝  ╚═╝     ╚═════╝ ╚══════╝
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
-------------------------------------------------------------------------

Installing AUR Softwares"
PROJECT_WD=Arch-Vortex
source $HOME/$PROJECT_WD/configs/setup.conf
source $HOME/$PROJECT_WD/scripts/scripts.sh


package_list $HOME/$PROJECT_WD/pkg-files/${DESKTOP_ENV}.txt
echo "INSTALLING: ${packages}"
pkg_install

if [[ ! $AUR_HELPER == none ]]; then
  cd ~
  git clone "https://aur.archlinux.org/$AUR_HELPER.git"
  cd ~/$AUR_HELPER
  makepkg -si --noconfirm
  package_list $HOME/$PROJECT_WD/pkg-files/aur-pkgs.txt
  echo "INSTALLING: ${packages}"
  $AUR_HELPER -S --noconfirm --needed ${packages}
fi


export PATH=$PATH:~/.local/bin

echo "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------"
exit
