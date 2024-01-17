#!/usr/bin/env bash

echo -ne "
-------------------------------------------------------------------------
  ██╗  ██╗ ██████╗ ██████╗ ████████╗██████╗██╗  ██╗     ██████╗ ███████╗
  ██║  ██║██╔═══██╗██╔══██╗╚══██╔══╝██╔═══ ╚██╗██╔╝    ██╔═══██╗██╔════╝
  ██║  ██║██║   ██║██████╔╝   ██║   ████╗   ╚███╔╝ ███╗██║   ██║███████╗
  ╚██╗██╔╝██║   ██║██╔══██╗   ██║   ██╔═╝   ██╔██╗ ╚══╝██║   ██║╚════██║
   ╚███╔╝ ╚██████╔╝██║  ██║   ██║   ██████╗██╔╝╚██╗    ╚██████╔╝███████║
    ╚══╝   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═════╝╚═╝  ╚═╝     ╚═════╝ ╚══════╝
                            original:github.com/ChrisTitusTech/ArchTitus
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
-------------------------------------------------------------------------
Setting up mirrors for optimal download"

source $CONFIGS_DIR/setup.conf

cat "$CONFIGS_DIR/setup.conf"

timedatectl set-ntp true
pacman -S --noconfirm archlinux-keyring
pacman -S --noconfirm --needed pacman-contrib terminus-font
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
pacman -S --noconfirm --needed reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
if [[ ${MIRROR} == "reflector" ]]; then
    reflector -a 48 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
else
    curl -L -o /etc/pacman.d/mirrorlist ${MIRROR}
    if [[ $? -eq 0 ]]; then
        echo "Custom mirrors list downloaded successfully."
    else
        echo "An error occurred while downloading the custom mirrors list."
        reflector -a 48 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
    fi
fi
mkdir /mnt &>/dev/null



echo "
-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------"

pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc



echo "
-------------------------------------------------------------------------
                    Formating Disk
-------------------------------------------------------------------------"

umount -A --recursive /mnt
wipefs -af ${DISK}
sgdisk -Z ${DISK}

sgdisk -a 2048 -o ${DISK}
sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' ${DISK}
sgdisk -n 2::+300M --typecode=2:ef00 --change-name=2:'EFIBOOT' ${DISK}
sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' ${DISK}

if [[ ! -d "/sys/firmware/efi" ]]; then
    sgdisk -A 1:set:2 ${DISK}
fi

partprobe ${DISK}



echo "
-------------------------------------------------------------------------
                    Creating Filesystems
-------------------------------------------------------------------------"

createsubvolumes () {
    for subvol in @ @home @var @tmp @.snapshots; do
        echo "createsubvolumes ${subvol}"
        btrfs subvolume create /mnt/${subvol}
    done
}

mount_subvol () {
    for subvol in home tmp var .snapshots; do
        echo "mount_subvol ${subvol}  |  ${1}"
        mkdir /mnt/${subvol}
        mount -o ${MOUNT_OPTIONS},subvol=@${subvol} ${1:-/dev/mapper/cryptroot} /mnt/${subvol}
    done
}

mountallsubvol () {
    echo "mountallsubvol"
    if [[ "${FS}" == "btrfs" ]]; then
        mount_subvol ${partition3}
    else
        mount_subvol
    fi
}

subvolumesetup () {
    echo "subvolumesetup"
    cd /mnt
    createsubvolumes
    cd /
    umount /mnt
    if [[ "${FS}" == "btrfs" ]]; then
        mount -o ${MOUNT_OPTIONS},subvol=@ ${partition3} /mnt
    else
        mount -o ${MOUNT_OPTIONS},subvol=@ /dev/mapper/cryptroot /mnt
    fi
    mkdir -p /mnt/{boot}
    mountallsubvol
}


if [[ "${DISK}" =~ "nvme" ]]; then
    partition2=${DISK}p2
    partition3=${DISK}p3
else
    partition2=${DISK}2
    partition3=${DISK}3
fi

partition_mkfs () {
    mkfs.vfat -f -F32 ${partition2}
    mkfs.${FS} -f ${partition3}
    mount ${partition3} /mnt
}

partition_luks_mkfs () {
    mkfs.vfat -F32 ${partition2}
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v --cipher aes-xts-plain64 --hash sha512 --use-random luksFormat ${partition3}
    echo -n "${LUKS_PASSWORD}" | cryptsetup open ${partition3} cryptroot
    luks_fs=$(echo ${FS} | sed 's/luks-//')
    mkfs.${luks_fs} /dev/mapper/cryptroot
    mount /dev/mapper/cryptroot /mnt
}

grab_uuid () {
    echo ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value ${partition3}) >> $CONFIGS_DIR/setup.conf
}

if [[ "${FS}" == "btrfs" ]]; then
    partition_mkfs
    subvolumesetup
elif [[ "${FS}" == "ext4" ]]; then
    partition_mkfs
elif [[ "$FS" == "luks-btrfs" ]]; then
    partition_luks_mkfs
    subvolumesetup
    grab_uuid
elif [[ "$FS" == "luks-ext4" ]]; then
    partition_luks_mkfs
    grab_uuid
fi


mkdir -p /mnt/boot/EFI
mount ${partition2} /mnt/boot/


if ! grep -qs '/mnt' /proc/mounts; then
    echo "Drive is not mounted can not continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi



echo "
-------------------------------------------------------------------------
                    Arch Install on Main Drive
-------------------------------------------------------------------------"

pacstrap /mnt base base-devel linux linux-firmware vim nano sudo archlinux-keyring wget libnewt --noconfirm --needed
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp -R ${SCRIPT_DIR} /mnt/root/$PROJECT_WD
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -U /mnt >> /mnt/etc/fstab
echo "
  Generated /etc/fstab:
"
cat /mnt/etc/fstab



echo "
-------------------------------------------------------------------------
                    GRUB BIOS Bootloader Install & Check
-------------------------------------------------------------------------"

if [[ ! -d "/sys/firmware/efi" ]]; then
    grub-install --boot-directory=/mnt/boot ${DISK}
else
    pacstrap /mnt efibootmgr --noconfirm --needed
fi



echo "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 1-setup.sh
-------------------------------------------------------------------------"
