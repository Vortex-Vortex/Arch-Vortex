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
-------------------------------------------------------------------------"

# Remove pacman Error for testing purposes on VM

#sed -i 's/SigLevel    = Required DatabaseOptional/SigLevel = Never/' /etc/pacman.conf
#sed -i 's/LocalFileSigLevel/#LocalFileSigLevel/' /etc/pacman.conf

PROJECT_WD=Arch-Vortex

source $HOME/$PROJECT_WD/configs/setup.conf
source $HOME/$PROJECT_WD/scripts/scripts.sh
echo "
-------------------------------------------------------------------------
                    Network Setup
-------------------------------------------------------------------------"

pacman -S --noconfirm --needed networkmanager dhclient
systemctl enable --now NetworkManager



echo "
-------------------------------------------------------------------------
                    Setting up mirrors for optimal download
-------------------------------------------------------------------------"

pacman -S --noconfirm --needed pacman-contrib curl
pacman -S --noconfirm --needed reflector rsync grub arch-install-scripts git
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

nc=$(grep -c ^processor /proc/cpuinfo)



echo "
-------------------------------------------------------------------------
                    You have " $nc" cores. And
			changing the makeflags for "$nc" cores. Aswell as
				changing the compression settings.
-------------------------------------------------------------------------"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $TOTAL_MEM -gt 8000000 ]]; then
sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /etc/makepkg.conf
sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /etc/makepkg.conf
fi



echo "
-------------------------------------------------------------------------
                    Setup Language to US and set locale
-------------------------------------------------------------------------"

sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
timedatectl --no-ask-password set-timezone ${TIMEZONE}
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
localectl --no-ask-password set-keymap ${KEYMAP}

sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

pacman -Sy --noconfirm --needed



echo "
-------------------------------------------------------------------------
                    Installing Base System
-------------------------------------------------------------------------"

package_list $HOME/$PROJECT_WD/pkg-files/pacman-pkgs.txt
echo "Running PKG_INSTALL"
pkg_install



echo "
-------------------------------------------------------------------------
                    Installing Microcode
-------------------------------------------------------------------------"

proc_type=$(lscpu)
if grep -E "GenuineIntel" <<< ${proc_type}; then
    echo "Installing Intel microcode"
    pacman -S --noconfirm --needed intel-ucode
    proc_ucode=intel-ucode.img
elif grep -E "AuthenticAMD" <<< ${proc_type}; then
    echo "Installing AMD microcode"
    pacman -S --noconfirm --needed amd-ucode
    proc_ucode=amd-ucode.img
fi



echo "
-------------------------------------------------------------------------
                    Adding User
-------------------------------------------------------------------------"
if [ $(whoami) = "root"  ]; then
    groupadd libvirt
    useradd -m -G wheel,libvirt -s /bin/bash $USERNAME
    echo "$USERNAME created, home directory created, added to wheel and libvirt group, default shell set to /bin/bash"

    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "$USERNAME password set"

    echo "root:$PASSWD" | chpasswd

	cp -R $HOME/$PROJECT_WD /home/$USERNAME/
    chown -R $USERNAME: /home/$USERNAME/$PROJECT_WD
    echo "Arch-Vortex copied to home directory"

	echo $NAME_OF_MACHINE > /etc/hostname
else
	echo "You are already a user proceed with aur installs"
fi


if [[ ${FS} == *"btrfs"* ]]; then
    sed -i "s/MODULES=()/MODULES=(btrfs)/" /etc/mkinitcpio.conf
    mkinitcpio -p linux
fi


if [[ ${FS} == *"luks"* ]]; then
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
    mkinitcpio -p linux
fi



echo "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 2-user.sh
-------------------------------------------------------------------------"
