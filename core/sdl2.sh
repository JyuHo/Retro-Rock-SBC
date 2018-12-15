#!/usr/bin/env bash

rp_module_id="sdl2"
rp_module_desc="SDL (Simple DirectMedia Layer) v2.x"
rp_module_licence="ZLIB https://hg.libsdl.org/SDL/raw-file/f426dbef4aa0/COPYING.txt"
rp_module_section=""
rp_module_flags=""

function get_ver_sdl2() {
    echo "2.0.9"
}

function get_pkg_ver_sdl2() {
    local ver="$(get_ver_sdl2)+1"
    isPlatform "rockpro64" && ver+="kms"
    isPlatform "rock64" && ver+="kms"
    isPlatform "tinker" && ver+="kms"

    echo "$ver"
}

function get_arch_sdl2() {
    echo "$(dpkg --print-architecture)"
}

function depends_sdl2() {
    local depends=(devscripts debhelper dh-autoreconf libasound2-dev libudev-dev libibus-1.0-dev libdbus-1-dev fcitx-libs-dev)
    isPlatform "kms" && depends+=(libdrm-dev libgbm-dev)
    getDepends "${depends[@]}"
}

function build_sdl2() {
    cd "$(get_pkg_ver_sdl2)"

    dpkg-buildpackage
    md_ret_require="$md_build/libsdl2-dev_$(get_pkg_ver_sdl2)_$(get_arch_sdl2).deb"
    local dest="$__tmpdir/archives/$__os_codename/$__platform"
    mkdir -p "$dest"
    cp ../*.deb "$dest/"
}

function remove_old_sdl2() {
    # remove our old libsdl2 packages
    hasPackage libsdl2 && dpkg --remove libsdl2 libsdl2-dev
}

function install_sdl2() {
    remove_old_sdl2
    # if the packages don't install completely due to missing dependencies the apt-get -y -f install will correct it
    if ! dpkg -i libsdl2-2.0-0_$(get_pkg_ver_sdl2)_$(get_arch_sdl2).deb libsdl2-dev_$(get_pkg_ver_sdl2)_$(get_arch_sdl2).deb; then
        apt-get -y -f install
    fi
    echo "libsdl2-dev hold" | dpkg --set-selections
}

function revert_sdl2() {
    aptUpdate
    local packaged="$(apt-cache madison libsdl2-dev | cut -d" " -f3 | head -n1)"
    if ! aptInstall --allow-downgrades --allow-change-held-packages libsdl2-2.0-0="$packaged" libsdl2-dev="$packaged"; then
        md_ret_errors+=("Failed to revert to OS packaged sdl2 versions")
    fi
}

function remove_sdl2() {
    apt-get remove -y --allow-change-held-packages libsdl2-dev libsdl2-2.0-0
    apt-get autoremove -y
}
