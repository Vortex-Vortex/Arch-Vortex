#!/usr/bin/env bash

CONFIG_FILE=$CONFIGS_DIR/setup.conf
if [ ! -f $CONFIG_FILE ]; then
    touch -f $CONFIG_FILE
fi


set_option() {
    if grep -Eq "^${1}.*" $CONFIG_FILE; then
        sed -i -e "/^${1}.*/d" $CONFIG_FILE
    fi
    echo "${1}=${2}" >>$CONFIG_FILE
}


set_password() {
    read -rs -p "Please enter $2 password: " PASSWORD1
    echo -ne "\n"
    read -rs -p "Please re-enter password: " PASSWORD2
    echo -ne "\n"
    if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
        set_option "$1" "$PASSWORD1"
    else
        echo -ne "ERROR! Passwords do not match. \n"
        set_password
    fi
}


root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        echo -ne "ERROR! This script must be run under the 'root' user!\n"
        exit 0
    fi
}


docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
        echo -ne "ERROR! Docker container is not supported (at the moment)\n"
        exit 0
    elif [[ -f /.dockerenv ]]; then
        echo -ne "ERROR! Docker container is not supported (at the moment)\n"
        exit 0
    fi
}


arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        echo -ne "ERROR! This script must be run in Arch Linux!\n"
        exit 0
    fi
}


pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo "ERROR! Pacman is blocked."
        echo -ne "If not running remove /var/lib/pacman/db.lck.\n"
        exit 0
    fi
}


background_checks() {
    root_check
    arch_check
    pacman_check
    docker_check
}


select_option() {

    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "$2   $1 "; }
    print_selected()   { printf "$2  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    get_cursor_col()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${COL#*[}; }
    key_input()         {
                        local key
                        IFS= read -rsn1 key 2>/dev/null >&2
                        if [[ $key = ""      ]]; then echo enter; fi;
                        if [[ $key = $'\x20' ]]; then echo space; fi;
                        if [[ $key = "k" ]]; then echo up; fi;
                        if [[ $key = "j" ]]; then echo down; fi;
                        if [[ $key = "h" ]]; then echo left; fi;
                        if [[ $key = "l" ]]; then echo right; fi;
                        if [[ $key = "a" ]]; then echo all; fi;
                        if [[ $key = "n" ]]; then echo none; fi;
                        if [[ $key = $'\x1b' ]]; then
                            read -rsn2 key
                            if [[ $key = [A || $key = k ]]; then echo up;    fi;
                            if [[ $key = [B || $key = j ]]; then echo down;  fi;
                            if [[ $key = [C || $key = l ]]; then echo right;  fi;
                            if [[ $key = [D || $key = h ]]; then echo left;  fi;
                        fi
    }
    print_options_multicol() {
        local curr_col=$1
        local curr_row=$2
        local curr_idx=0

        local idx=0
        local row=0
        local col=0

        curr_idx=$(( $curr_col + $curr_row * $colmax ))

        for option in "${options[@]}"; do

            row=$(( $idx/$colmax ))
            col=$(( $idx - $row * $colmax ))

            cursor_to $(( $startrow + $row + 1)) $(( $offset * $col + 1))
            if [ $idx -eq $curr_idx ]; then
                print_selected "$option"
            else
                print_option "$option"
            fi
            ((idx++))
        done
    }

    for opt; do printf "\n"; done

    local return_value=$1
    local lastrow=`get_cursor_row`
    local lastcol=`get_cursor_col`
    local startrow=$(($lastrow - $#))
    local startcol=1
    local lines=$( tput lines )
    local cols=$( tput cols )
    local colmax=$2
    local offset=$(( $cols / $colmax ))

    local size=$4
    shift 4

    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active_row=0
    local active_col=0
    while true; do
        print_options_multicol $active_col $active_row
        case `key_input` in
            enter)  break;;
            up)     ((active_row--));
                    if [ $active_row -lt 0 ]; then active_row=0; fi;;
            down)   ((active_row++));
                    if [ $active_row -ge $(( ${#options[@]} / $colmax ))  ]; then active_row=$(( ${#options[@]} / $colmax )); fi;;
            left)     ((active_col=$active_col - 1));
                    if [ $active_col -lt 0 ]; then active_col=0; fi;;
            right)     ((active_col=$active_col + 1));
                    if [ $active_col -ge $colmax ]; then active_col=$(( $colmax - 1 )) ; fi;;
        esac
    done

    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $(( $active_col + $active_row * $colmax ))
}
# @description Displays ArchTitus logo
# @noargs
logo () {
# This will be shown on every set as user is progressing
echo "
-------------------------------------------------------------------------
  ██╗  ██╗ ██████╗ ██████╗ ████████╗██████╗██╗  ██╗     ██████╗ ███████╗
  ██║  ██║██╔═══██╗██╔══██╗╚══██╔══╝██╔═══ ╚██╗██╔╝    ██╔═══██╗██╔════╝
  ██║  ██║██║   ██║██████╔╝   ██║   ████╗   ╚███╔╝ ███╗██║   ██║███████╗
  ╚██╗██╔╝██║   ██║██╔══██╗   ██║   ██╔═╝   ██╔██╗ ╚══╝██║   ██║╚════██║
   ╚███╔╝ ╚██████╔╝██║  ██║   ██║   ██████╗██╔╝╚██╗    ╚██████╔╝███████║
    ╚══╝   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═════╝╚═╝  ╚═╝     ╚═════╝ ╚══════╝
-------------------------------------------------------------------------
                        System Configuration
-------------------------------------------------------------------------"
}


filesystem () {
echo "
Please select your file system for both boot and root"

options=("btrfs" "ext4" "luks-btrfs" "luks-ext4" "exit")
select_option $? 1 "${options[@]}"

case $? in
0) set_option FS btrfs;;
1) set_option FS ext4;;
2)
    set_password "LUKS_PASSWORD" "LUKS"
    set_option FS luks-btrfs;;
3)
    set_password "LUKS_PASSWORD" "LUKS"
    set_option FS luks-ext4;;
4) exit ;;
*) echo "Wrong option please select again"; filesystem;;
esac
}


timezone () {
time_zone="$(curl --fail https://ipapi.co/timezone)"
echo "
System detected your timezone to be '$time_zone' \n"
echo "Is this correct?"

options=("Yes" "No")
select_option $? 1 "${options[@]}"

case ${options[$?]} in
    y|Y|yes|Yes|YES)
    echo "${time_zone} set as timezone"
    set_option TIMEZONE $time_zone;;
    n|N|no|NO|No)
    read -p "Please enter your desired timezone e.g. America/Sao_Paulo :" new_timezone
    echo "${new_timezone} set as timezone"
    set_option TIMEZONE $new_timezone;;
    *) echo "Wrong option. Try again";timezone;;
esac
}


drivessd () {
echo "
Is this an ssd? yes/no:"

options=("Yes" "No")
select_option $? 1 "${options[@]}"

case ${options[$?]} in
    y|Y|yes|Yes|YES)
    set_option MOUNT_OPTIONS "noatime,space_cache=v2,compress=zstd,ssd,discard=async";;
    n|N|no|NO|No)
    set_option MOUNT_OPTIONS "noatime,space_cache=v2,compress=zstd";;
    *) echo "Wrong option. Try again";drivessd;;
esac
}


diskpart () {
echo -e "
------------------------------------------------------------------------
    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
    Please make sure you know what you are doing because
    after formating your disk there is no way to get data back
------------------------------------------------------------------------
"

PS3='
Select the disk to install on: '
options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

select_option $? 1 "${options[@]}"
disk=${options[$?]%|*}

echo -e "\n${disk%|*} selected \n"
    set_option DISK ${disk%|*}

drivessd
}


keymap () {
echo -n "
Please select keyboard layout from this list"
# These are default key maps as presented in official arch repo archinstall
options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru sg ua uk br-abnt2)

select_option $? 4 "${options[@]}"
keymap=${options[$?]}

echo "Chosen keyboard layout: ${keymap} "
set_option KEYMAP $keymap
}


rootpasswd () {
set_password "PASSWD" "ROOT"
}


userinfo () {
read -p "Please enter your username: " username
set_option USERNAME ${username,,}
set_password "PASSWORD" "USER"
read -rep "Please enter your hostname: " nameofmachine
set_option NAME_OF_MACHINE $nameofmachine
}


aurhelper () {
  echo "Please enter your desired AUR helper:"
  options=(paru yay pikaur aura trizen pacaur none)
  select_option $? 4 "${options[@]}"
  aur_helper=${options[$?]}
  set_option AUR_HELPER $aur_helper
}


desktopenv () {
  echo "Please select your desired Desktop Enviroment:"
  options=( `for f in pkg-files/*.txt; do echo "$f" | sed -r "s/.+\/(.+)\..+/\1/;/pkgs/d"; done` )
  select_option $? 4 "${options[@]}"
  desktop_env=${options[$?]}
  set_option DESKTOP_ENV $desktop_env
}


mirror_list () {
  echo "Select mirror list method:\n\n
  Reflector: uses command 'reflector -a 48 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist' to grab mirrors
  File: use this if reflector is filtering slow mirrors, assign a (ix.io/?) url with the mirrors file"
  options=(reflector file)
  select_option $? 4 "${options[@]}"
  case ${options[$?]} in
    reflector)
    set_option MIRROR "reflector";;
    file)
    read -p "Please enter your ix.io url file:" mirror_url
    set_option MIRROR $mirror_url;;
    *) echo "Wrong option. Try again";mirror_list;;
  esac
}


installtype () {
  echo -e "Please select type of installation:\n\n
  Full install: Installs full featured desktop enviroment, with added apps and themes needed for everyday use\n
  Minimal Install: Installs only a few selected apps to get you started"
  options=(FULL MINIMAL)
  select_option $? 4 "${options[@]}"
  install_type=${options[$?]}
  set_option INSTALL_TYPE $install_type
}


grubtheme () {
  echo -ne "Please select your GRUB theme (Post BIOS-screen loading menu)"
  options=( `for f in configs/boot/grub/themes/*; do echo "$(basename $f)"; done` none )
  select_option $? 4 "${options[@]}"
  grub_theme=${options[$?]}
  set_option THEME_NAME $grub_theme
}

project_pwd () {
  repository=$(basename `pwd`)
  set_option PROJECT_WD $repository
  echo "Current repository: ${repository}
  "
}

project_pwd
background_checks
clear
logo
rootpasswd
clear
logo
userinfo
clear
logo
desktopenv
clear
logo
aurhelper
clear
logo
installtype
clear
logo
mirror_list
clear
logo
grubtheme
clear
logo
diskpart
clear
logo
filesystem
clear
logo
timezone
clear
logo
keymap
clear
