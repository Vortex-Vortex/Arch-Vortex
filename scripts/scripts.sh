#!/usr/bin/env bash

package_list () {
    packages=$(tr -s '\n' ' ' < $1)

    if [[ ${INSTALL_TYPE} == 'FULL' ]]; then
        packages=${packages/ \-\-END OF MINIMAL INSTALL\-\- / }
        echo 'Installing Full list'
    elif [[ ${INSTALL_TYPE} == 'MINIMAL' ]]; then
        packages=$(echo $packages | sed 's/ \-\-END OF MINIMAL INSTALL.*/ /g')
        echo 'Installing Partial list'
    fi
}

pkg_install () {
    echo "INSTALLING: ${packages}"
    lock=${1:-true}
    err_package=''
    if ! sudo pacman -S --noconfirm --needed $packages 2> /tmp/pacman_error; then
        sed -i '/warning/d' /tmp/pacman_error
        while read line; do
            if echo $line | grep -q '^error: target not found:'; then
                match=$(echo $line | sed -E 's/^error: target not found: (.+)/\1/')
                err_package+=" ${match}"
            elif echo $line | grep -q '^error' && $lock; then
                pkg_install false
            else
                echo "Error: Failed to install packages"
                exit 1
            fi
        done < /tmp/pacman_error

        echo "The following packages are invalid to install using pacman"
        echo "Please check spelling and availability on Arch repositories"
        echo "Packages: ${err_package}"
        read -n 1 -s -r -p "press any key to enter nano and make changes needed on packages file..."
        vim $package_file
        package_list $package_file
        pkg_install
    fi
    echo "Packages installed successfully"
}
