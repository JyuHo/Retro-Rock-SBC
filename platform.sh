#!/usr/bin/env bash

function setup_env() {

    __ERRMSGS=()
    __INFMSGS=()

    # if no apt-get we need to fail
    [[ -z "$(which apt-get)" ]] && fatalError "Unsupported OS - No apt-get command found"

    __memory_phys=$(free -m | awk '/^Mem:/{print $2}')
    __memory_total=$(free -m -t | awk '/^Total:/{print $2}')

    __has_binaries=0

    get_platform
    get_os_version
    get_retro-armbian_depends

    __gcc_version=$(gcc -dumpversion)

    [[ -z "${CFLAGS}" ]] && export CFLAGS="${__default_cflags}"
    [[ -z "${CXXFLAGS}" ]] && export CXXFLAGS="${__default_cxxflags}"
    [[ -z "${ASFLAGS}" ]] && export ASFLAGS="${__default_asflags}"
    [[ -z "${MAKEFLAGS}" ]] && export MAKEFLAGS="${__default_makeflags}"

    # test if we are in a chroot
    if [[ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]]; then
        [[ -z "$QEMU_CPU" && -n "$__qemu_cpu" ]] && export QEMU_CPU=$__qemu_cpu
        __chroot=1
    else
        __chroot=0
    fi

    if [[ -z "$__nodialog" ]]; then
        __nodialog=0
    fi
}

function get_os_version() {
    # make sure lsb_release is installed
    getDepends lsb-release

    # get os distributor id, description, release number and codename
    local os
    mapfile -t os < <(lsb_release -sidrc)
    __os_id="${os[0]}"
    __os_desc="${os[1]}"
    __os_release="${os[2]}"
    __os_codename="${os[3]}"
    
    local error=""
    case "$__os_id" in
        Debian)
            # Debian unstable is not officially supported though
            if [[ "$__os_release" == "unstable" ]]; then
                __os_release=10
            fi

            if compareVersions "$__os_release" lt 8; then
                error="You need Debian Jessie or newer"
            fi

            # get major version (8 instead of 8.0 etc)
            __os_debian_ver="${__os_release%%.*}"
            ;;
        Ubuntu)
            if compareVersions "$__os_release" lt 14.04; then
                error="You need Ubuntu 14.04 or newer"
            elif compareVersions "$__os_release" lt 16.10; then
                __os_debian_ver="8"
            else
                __os_debian_ver="9"
            fi
            __os_ubuntu_ver="$__os_release"
            ;;
        *)
            error="Unsupported OS"
            ;;
    esac
    
    [[ -n "$error" ]] && fatalError "$error\n\n$(lsb_release -idrc)"

    # add 32bit/64bit to platform flags
    __platform_flags+=" $(getconf LONG_BIT)bit"

}

function get_retro-armbian_depends() {
    local depends=(git dialog wget gcc g++ build-essential unzip xmlstarlet python-pyudev ca-certificates)

    if ! getDepends "${depends[@]}"; then
        fatalError "Unable to install packages required by $0 - ${md_ret_errors[@]}"
    fi
}

function get_platform() {
    local architecture="$(uname --machine)"
    if [[ -z "$__platform" ]]; then
        if grep -q "RockPro64" /sys/firmware/devicetree/base/model; then
            __platform="rockpro64"
        elif grep -q "Rock64" /sys/firmware/devicetree/base/model; then
            __platform="rock64"
        elif grep -q "Tinker Board" /sys/firmware/devicetree/base/model; then
            __platform="tinker"
        fi

    fi

    if ! fnExists "platform_${__platform}"; then
        fatalError "Unknown platform - please manually set the __platform variable to one of the following: $(compgen -A function platform_ | cut -b10- | paste -s -d' ')"
    fi

    platform_${__platform}
    [[ -z "$__default_cxxflags" ]] && __default_cxxflags="$__default_cflags"
}

function platform_tinker() {
    __default_cflags="-O2 -marm -march=armv7-a -mtune=cortex-a17 -mfpu=neon-vfpv4 -mfloat-abi=hard -ftree-vectorize -funsafe-math-optimizations"
    __default_cflags+=" -DGL_GLEXT_PROTOTYPES"
    __default_asflags=""
    __default_makeflags="-j2"
    __platform_flags="arm armv7 neon kms gles"
}

function platform_rock64() {
    if [[ "$(getconf LONG_BIT)" -eq 32 ]]; then
        __default_cflags="-O2 -march=armv8-a+crc -mtune=cortex-a53 -mfpu=neon-fp-armv8"
        __platform_flags="arm armv8 neon kms gles"
    else
        __default_cflags="-O2 -march=native"
        __platform_flags="aarch64 kms gles"
    fi
    __default_cflags+=" -ftree-vectorize -funsafe-math-optimizations"
    # required for mali headers to define GL functions
    __default_cflags+=" -DGL_GLEXT_PROTOTYPES"
    __default_asflags=""
    __default_makeflags="-j2"
}

function platform_rockpro64() {
    __default_cflags="-O2 -march=armv8.1-a+crc -mtune=cortex-a73.cortex-a53"
    __default_cflags+=" -ftree-vectorize -funsafe-math-optimizations"
    # required for mali headers to define GL functions
    __default_cflags+=" -DGL_GLEXT_PROTOTYPES"
    __default_asflags=""
    __default_makeflags="-j2"
    __platform_flags="aarch64 kms gles"
}
