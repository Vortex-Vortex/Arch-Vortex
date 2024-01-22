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

Final Setup and Configurations
GRUB EFI Bootloader Install & Check"

PROJECT_WD=Arch-Vortex
source ${HOME}/$PROJECT_WD/configs/setup.conf

if [[ -d "/sys/firmware/efi" ]]; then
    grub-install --efi-directory=/boot ${DISK}
fi



echo "
-------------------------------------------------------------------------
               Creating (and Theming) Grub Boot Menu
-------------------------------------------------------------------------"

if [[ "${FS}" == "luks-btrfs" || "${FS}" == "luks-ext4" ]]; then
sed -i "s%GRUB_CMDLINE_LINUX=.*%GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:cryptroot root=/dev/mapper/cryptroot\"%g" /etc/default/grub
fi


if [[ ! "${THEME_NAME}" == "none" ]]; then
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub

  echo -e "Installing Dark Matter Grub theme..."
  THEME_DIR="/boot/grub/themes"
  echo -e "Creating the theme directory..."
  mkdir -p "${THEME_DIR}/${THEME_NAME}"
  echo -e "Copying the theme..."
  cd ${HOME}/$PROJECT_WD
  cp -a configs${THEME_DIR}/${THEME_NAME}/* ${THEME_DIR}/${THEME_NAME}
  echo -e "Backing up Grub config..."
  cp -an /etc/default/grub /etc/default/grub.bak
  echo -e "Setting the theme as the default..."
  grep "GRUB_THEME=" /etc/default/grub 2>&1 >/dev/null && sed -i '/GRUB_THEME=/d' /etc/default/grub
  echo "GRUB_THEME=\"${THEME_DIR}/${THEME_NAME}/theme.txt\"" >> /etc/default/grub
  echo -e "Updating grub..."
fi

grub-mkconfig -o /boot/grub/grub.cfg
echo -e "All set!"



echo "
-------------------------------------------------------------------------
               Enabling (and Theming) Login Display Manager
-------------------------------------------------------------------------"

if [[ ${DESKTOP_ENV} == "kde" || ${DESKTOP_ENV} == "awesome" ]]; then
  systemctl enable sddm.service
  if [[ ${INSTALL_TYPE} == "FULL" ]]; then
    echo [Theme] >>  /etc/sddm.conf
    echo Current=Nordic >> /etc/sddm.conf
  fi

elif [[ "${DESKTOP_ENV}" == "gnome" ]]; then
  systemctl enable gdm.service

elif [[ "${DESKTOP_ENV}" == "lxde" ]]; then
  systemctl enable lxdm.service

elif [[ "${DESKTOP_ENV}" == "openbox" ]]; then
  systemctl enable lightdm.service
  if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
    # Set default lightdm-webkit2-greeter theme to Litarvan
    sed -i 's/^webkit_theme\s*=\s*\(.*\)/webkit_theme = litarvan #\1/g' /etc/lightdm/lightdm-webkit2-greeter.conf
    # Set default lightdm greeter to lightdm-webkit2-greeter
    sed -i 's/#greeter-session=example.*/greeter-session=lightdm-webkit2-greeter/g' /etc/lightdm/lightdm.conf
  fi
fi



echo "
-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------"

systemctl enable cups.service
echo "  Cups enabled"
systemctl enable ntpd.service
echo "  NTP enabled"
systemctl disable dhcpcd.service
echo "  DHCP disabled"
systemctl stop dhcpcd.service
echo "  DHCP stopped"
systemctl enable NetworkManager.service
echo "  NetworkManager enabled"
systemctl enable bluetooth
echo "  Bluetooth enabled"
systemctl enable avahi-daemon.service
echo "  Avahi enabled"



if [[ ${INSTALL_TYPE} == "FULL" ]]; then
    echo "
    -------------------------------------------------------------------------
                          Customizing Environment
    -------------------------------------------------------------------------"

    for file in $HOME/$PROJECT_WD/{arch-theming.tar.gz,arch-config.tar.gz}; do
        tar -xzvf $file -C /home/$USERNAME
    done
    mkdir /home/$USERNAME/.local/share/
    mv /home/$USERNAME/{color-schemes,nemo} -t /home/$USERNAME/.local/share/
    mkdir -v /home/$USERNAME/.wallpapers
    cp $HOME/$PROJECT_WD/pkg-files/wallpapers-pkgs.txt /home/$USERNAME/.wallpapers/
    while read url; do
        wget "$url" -P /home/$USERNAME/.wallpapers/ > /dev/null &
        if [[ $(jobs -r -p | wc -l) -ge 5 ]]; then
            wait -n
        fi; done < /home/$USERNAME/.wallpapers/wallpapers-pkgs.txt

fi
chown -R $USERNAME /home/$USERNAME

echo "
-------------------------------------------------------------------------
                Customizing rofi and awesome
-------------------------------------------------------------------------"

if [[ ${DESKTOP_ENV} == "awesome" ]]; then
    git clone -v https://github.com/Vortex-Vortex/Vortex-Awesome /home/$USERNAME/.config/awesome
    mkdir -pv /home/$USERNAME/.config/rofi
    cp -v /home/$USERNAME/.config/awesome/theme/config.rasi /home/$USERNAME/.config/rofi/config.rasi
    sed -i '/@import/c\@import "/home/'$USERNAME'/.config/awesome/theme/sidebar.rasi"' /home/$USERNAME/.config/rofi/config.rasi
    chmod -R a=xrw /home/$USERNAME/.config/
fi

#sed -i 's/SigLevel = Never/SigLevel    = Required DatabaseOptional/' /etc/pacman.conf
#sed -i 's/#LocalFileSigLevel/LocalFileSigLevel/' /etc/pacman.conf


echo "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------"

sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# &/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# &/' /etc/sudoers

sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

rm -r $HOME/$PROJECT_WD
rm -r /home/$USERNAME/$PROJECT_WD

cd $pwd
