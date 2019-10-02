#!/bin/bash

#NVCH_VERSION="8.2.15.8-dmo1"
NVCH_VERSION="9.0.18.1-dmo1"

# Builds the DEB inside the Docker container

set -o errexit
set -o xtrace

# Prepare the cross-toolchain
prepare_crossbuild_env_armhf() {
    # Prepare the Ubuntu-specific cross-build requirements
    if [[ $( lsb_release -i -s ) == "Ubuntu" ]]; then
        CODENAME="$( lsb_release -c -s )"
        # Remove the default sources.list
        rm /etc/apt/sources.list
        # Add arch-specific list files
        cat <<EOF > /etc/apt/sources.list.d/amd64.list
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
EOF
        cat <<EOF > /etc/apt/sources.list.d/armhf.list
deb [arch=armhf] http://ports.ubuntu.com/ ${CODENAME} main restricted universe multiverse
deb [arch=armhf] http://ports.ubuntu.com/ ${CODENAME}-updates main restricted universe multiverse
deb [arch=armhf] http://ports.ubuntu.com/ ${CODENAME}-backports main restricted universe multiverse
deb [arch=armhf] http://ports.ubuntu.com/ ${CODENAME}-security main restricted universe multiverse
EOF
    fi
    # Add armhf architecture
    dpkg --add-architecture armhf
    # Update and install cross-gcc-dev
    apt-get update
    yes | apt-get install -y cross-gcc-dev
    # Generate gcc cross source
    TARGET_LIST="armhf" cross-gcc-gensource ${GCC_VER}
    # Install dependencies
    pushd cross-gcc-packages-amd64/cross-gcc-${GCC_VER}-armhf
    ln -fs /usr/share/zoneinfo/America/Toronto /etc/localtime
    yes | apt-get install -y gcc-${GCC_VER}-source libstdc++6-armhf-cross binutils-arm-linux-gnueabihf bison flex libtool gdb sharutils netbase libmpc-dev libmpfr-dev libgmp-dev systemtap-sdt-dev autogen expect chrpath zlib1g-dev zip libc6-dev:armhf linux-libc-dev:armhf libgcc1:armhf libcurl4-openssl-dev:armhf libfontconfig1-dev:armhf libfreetype6-dev:armhf liblttng-ust0:armhf libstdc++6:armhf
    popd
}
prepare_crossbuild_env_arm64() {
    # Prepare the Ubuntu-specific cross-build requirements
    if [[ $( lsb_release -i -s ) == "Ubuntu" ]]; then
        CODENAME="$( lsb_release -c -s )"
        # Remove the default sources.list
        rm /etc/apt/sources.list
        # Add arch-specific list files
        cat <<EOF > /etc/apt/sources.list.d/amd64.list
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
EOF
        cat <<EOF > /etc/apt/sources.list.d/arm64.list
deb [arch=arm64] http://ports.ubuntu.com/ ${CODENAME} main restricted universe multiverse
deb [arch=arm64] http://ports.ubuntu.com/ ${CODENAME}-updates main restricted universe multiverse
deb [arch=arm64] http://ports.ubuntu.com/ ${CODENAME}-backports main restricted universe multiverse
deb [arch=arm64] http://ports.ubuntu.com/ ${CODENAME}-security main restricted universe multiverse
EOF
    fi
    # Add armhf architecture
    dpkg --add-architecture arm64
    # Update and install cross-gcc-dev
    apt-get update
    yes | apt-get install -y cross-gcc-dev
    # Generate gcc cross source
    TARGET_LIST="arm64" cross-gcc-gensource ${GCC_VER}
    # Install dependencies
    pushd cross-gcc-packages-amd64/cross-gcc-${GCC_VER}-arm64
    ln -fs /usr/share/zoneinfo/America/Toronto /etc/localtime
    yes | apt-get install -y gcc-${GCC_VER}-source libstdc++6-arm64-cross binutils-aarch64-linux-gnu bison flex libtool gdb sharutils netbase libmpc-dev libmpfr-dev libgmp-dev systemtap-sdt-dev autogen expect chrpath zlib1g-dev zip libc6-dev:arm64 linux-libc-dev:arm64 libgcc1:arm64 libcurl4-openssl-dev:arm64 libfontconfig1-dev:arm64 libfreetype6-dev:arm64 liblttng-ust0:arm64 libstdc++6:arm64
    popd
}

# Set the architecture-specific options
case ${ARCH} in
    'amd64')
        CONFIG_SITE=""
        DEP_ARCH_OPT=""
        BUILD_ARCH_OPT=""
    ;;
    'armhf')
        prepare_crossbuild_env_armhf
        ln -s /usr/bin/arm-linux-gnueabihf-gcc-6 /usr/bin/arm-linux-gnueabihf-gcc
        CONFIG_SITE="/etc/dpkg-cross/cross-config.${ARCH}"
        DEP_ARCH_OPT="--host-arch armhf"
        BUILD_ARCH_OPT="-aarmhf"
    ;;
    'arm64')
        prepare_crossbuild_env_arm64
        #ln -s /usr/bin/arm-linux-gnueabihf-gcc-6 /usr/bin/arm-linux-gnueabihf-gcc
        CONFIG_SITE="/etc/dpkg-cross/cross-config.${ARCH}"
        DEP_ARCH_OPT="--host-arch arm64"
        BUILD_ARCH_OPT="-aarm64"
    ;;
esac

# Download and install the nvidia headers from deb-multimedia
wget -O nv-codec-headers.deb https://www.deb-multimedia.org/pool/main/n/nv-codec-headers-dmo/nv-codec-headers_${NVCH_VERSION}_all.deb
dpkg -i nv-codec-headers.deb
apt -yf install

# Move to source directory
pushd ${SOURCE_DIR}

# Apply Jellyfin-specific patches
for patchname in jf-patches/*.patch
do
    git apply "$patchname"
done

# Install dependencies and build the deb
yes | mk-build-deps -i ${DEP_ARCH_OPT}
dpkg-buildpackage -b -rfakeroot -us -uc ${BUILD_ARCH_OPT}

popd

# Move the artifacts out
mkdir -p ${ARTIFACT_DIR}/deb
mv /jellyfin-ffmpeg_* ${ARTIFACT_DIR}/deb/
chown -Rc $(stat -c %u:%g ${ARTIFACT_DIR}) ${ARTIFACT_DIR}
