#!/usr/bin/env bash

set -e

chromiumos_short_version=R143

chromiumos_long_version=$(git ls-remote https://chromium.googlesource.com/chromiumos/third_party/kernel/ | grep "refs/heads/release-${chromiumos_short_version}" | head -1 | sed -e 's#.*\t##' -e 's#chromeos-.*##' | sort -u | cut -d'-' -f2,3)

chromiumos_board=reven

rm -rf ./build_env

sudo -u ${SUDO_USER} bash <<REPO_INIT
set -e
mkdir -p ./build_env/chromiumos
cd ./build_env/chromiumos
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ../depot_tools
export PATH=$(echo \${PWD})/../depot_tools:/usr/sbin:/usr/bin:/sbin:/bin:\${PATH}
repo init -u https://chromium.googlesource.com/chromiumos/manifest.git -b release-${chromiumos_long_version} -g minilayout < /dev/null
repo sync -j4
REPO_INIT

cd ./build_env/chromiumos
export PATH=$(echo ${PWD})/../depot_tools:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}

cros_sdk <<COMMANDS
set -e
sudo emerge sys-devel/llvm
setup_board --board=${chromiumos_board}
sudo rm /mnt/host/source/src/third_party/chromiumos-overlay/profiles/targets/chromeos/package.provided
sudo rm /mnt/host/source/src/third_party/chromiumos-overlay/profiles/targets/chromeos/package.mask
sudo sed -i -z 's@local targetenv@local targetenv\n\treturn@g' /mnt/host/source/src/third_party/chromiumos-overlay/profiles/base/profile.bashrc
sudo sed -i '/virtual\/perl-Math-BigInt/d' /mnt/host/source/src/third_party/portage-stable/dev-lang/perl/perl-*.ebuild
sudo sed -i '/sys-libs\/glibc/!d' /build/reven/etc/portage/profile/package.provided
echo -e 'FEATURES="-buildpkg -collision-detect -force-mirror -getbinpkg -protect-owned -splitdebug"\nMAKEOPTS="--jobs 2"\nEMERGE_DEFAULT_OPTS="--jobs 2"\nUSE="-pam"' | sudo tee /build/reven/etc/portage/make.conf
sudo mkdir -p /build/reven/etc/portage/env /build/reven/etc/portage/profile
echo -e 'sys-libs/libxcrypt static-libs' | sudo tee /build/reven/etc/portage/profile/package.use
echo -e 'dev-lang/perl perl.conf\ndev-util/cmake cmake.conf' | sudo tee /build/reven/etc/portage/package.env
echo -e 'CXXFLAGS="-fexceptions -funwind-tables -fasynchronous-unwind-tables"\nCXXEXCEPTIONS=1' | sudo tee /build/reven/etc/portage/env/cmake.conf
echo -e 'EXTRA_ECONF="-Dbyteorder=1234"' | sudo tee /build/reven/etc/portage/env/perl.conf
emerge-${chromiumos_board} sys-apps/baselayout
echo "root:x:0:0:root:/root:/bin/bash" | sudo tee /build/reven/etc/passwd
emerge-${chromiumos_board} acct-user/chronos acct-group/chronos acct-group/root app-admin/sudo app-alternatives/awk app-alternatives/gzip app-editors/nano app-misc/ca-certificates app-misc/jq app-misc/mime-types app-shells/bash chromeos-base/vboot_reference dev-build/libtool dev-build/meson dev-lang/go dev-lang/perl dev-lang/python dev-lang/python-exec dev-lang/python-exec-conf dev-libs/json-glib dev-libs/libtasn1 dev-python/ensurepip-pip dev-python/ensurepip-setuptools dev-python/ensurepip-wheels dev-python/installer dev-python/packaging dev-python/setuptools dev-python/wheel dev-util/cmake dev-util/ninja dev-util/pkgconf dev-vcs/git media-libs/libjpeg-turbo media-libs/libpng net-misc/curl net-misc/rsync net-misc/wget sys-apps/attr sys-apps/coreutils sys-apps/diffutils sys-apps/file sys-apps/findutils sys-apps/flashrom sys-apps/gawk sys-apps/grep sys-apps/install-xattr sys-apps/locale-gen sys-apps/mawk sys-apps/sandbox sys-apps/sed sys-apps/shadow sys-apps/texinfo sys-apps/util-linux sys-boot/efibootmgr sys-devel/autoconf sys-devel/autoconf-wrapper sys-devel/automake sys-devel/automake-wrapper sys-devel/binutils sys-devel/binutils-config sys-devel/bison sys-devel/flex sys-devel/gcc sys-devel/gcc-config sys-devel/gnuconfig sys-devel/m4 sys-devel/make sys-devel/patch sys-fs/dosfstools sys-fs/ntfs3g sys-kernel/linux-headers sys-libs/libxcrypt sys-process/procps
for i in  /build/reven/usr/x86_64-cros-linux-gnu/gcc-bin/*/*; do if [ "\$(readlink \${i})" == "host_wrapper" ]; then sudo rm "\${i}"; sudo ln -s "\$(basename \${i}).real" "\${i}"; fi; done
sudo mkdir /build/reven/dev /build/reven/proc /build/reven/sys
sudo rm -r /build/reven/build /build/reven/packages /build/reven/sys-include /build/reven/usr/local /build/reven/tmp/portage 
COMMANDS

cd ../..

rm -f ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz
tar zcf ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz -C ./build_env/chromiumos/out/build/reven .
chown ${SUDO_UID}:$(id -g ${SUDO_UID}) ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz

