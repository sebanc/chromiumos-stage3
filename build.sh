#!/usr/bin/env bash

set -e

chromiumos_short_version=R144

chromiumos_long_version=$(git ls-remote https://chromium.googlesource.com/chromiumos/third_party/kernel/ | grep "refs/heads/release-${chromiumos_short_version}" | head -1 | sed -e 's#.*\t##' -e 's#chromeos-.*##' | sort -u | cut -d'-' -f2,3)

chromiumos_board=reven

rm -rf ./chroot
mkdir ./chroot
curl -L https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst -o /tmp/archlinux-bootstrap.tar.zst
tar --zstd --strip 1 -xf /tmp/archlinux-bootstrap.tar.zst -C ./chroot

cat >./chroot/init <<CHROOT_INIT
#!/bin/bash
set -e

export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export TERM=xterm-256color

echo 'nameserver 8.8.8.8' > /etc/resolv.conf

cur_speed=0; for i in https://geo.mirror.pkgbuild.com https://mirrors.rit.edu/archlinux https://archlinux.mirror.digitalpacific.com.au; do if ! avg_speed=\$(curl -fsS -m 5 -r 0-1048576 -w '%{speed_download}' -o /dev/null --url "\${i}/core/os/x86_64/core.db" 2> /dev/null); then avg_speed=0; fi; echo Download speed rating for mirror \${i} is \${avg_speed}; if [ \${avg_speed} -gt \${cur_speed} ]; then cur_speed=\${avg_speed}; default_mirror=\${i}; fi; done; echo Using mirror \${default_mirror}; sed -i "s@#Server = \${default_mirror}@Server = \${default_mirror}@g" /etc/pacman.d/mirrorlist

pacman-key --init
pacman-key --populate
pacman -Syu --noconfirm --needed git openssh python sudo tar xz zstd

useradd -s /bin/bash -m 'temp'
echo -e 'temp\ntemp' | passwd 'temp'
echo 'temp      ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-wheel
cd /home/temp

sudo -u temp bash << 'CHROOT_USER'
set -e
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
mkdir -p ./build_env/chromiumos
cd ./build_env/chromiumos
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ../depot_tools
export PATH=/home/temp/build_env/depot_tools:/usr/sbin:/usr/bin:/sbin:/bin
repo init -u https://chromium.googlesource.com/chromiumos/manifest.git -b release-${chromiumos_long_version} -g minilayout < /dev/null
repo sync -j4

cros_sdk <<'CHROMIUMOS_BUILD'
set -e
setup_board --board=${chromiumos_board}
sudo rm /mnt/host/source/src/third_party/chromiumos-overlay/profiles/targets/chromeos/package.provided
sudo rm /mnt/host/source/src/third_party/chromiumos-overlay/profiles/targets/chromeos/package.mask
sudo sed -i -z 's@local targetenv@local targetenv\n\treturn@g' /mnt/host/source/src/third_party/chromiumos-overlay/profiles/base/profile.bashrc
sudo rm -f /mnt/host/source/src/third_party/chromiumos-overlay/sys-apps/sed/sed.bashrc
sudo rm -f /mnt/host/source/src/third_party/chromiumos-overlay/sys-devel/bc/bc.bashrc
sudo rm -f /mnt/host/source/src/third_party/chromiumos-overlay/sys-apps/mawk/mawk.bashrc
sudo sed -i -z 's@local sysroot_wrapper_file=host_wrapper@return\n\t\tlocal sysroot_wrapper_file=host_wrapper@g' /mnt/host/source/src/third_party/chromiumos-overlay/sys-devel/gcc/gcc-*.ebuild
sudo sed -i '/virtual\/perl-Math-BigInt/d' /mnt/host/source/src/third_party/portage-stable/dev-lang/perl/perl-*.ebuild
echo -e '#!/bin/bash\nexec \$1' | sudo tee /mnt/host/source/src/platform2/common-mk/meson_test.py
sudo sed -i '/sys-libs\/glibc/!d' /build/reven/etc/portage/profile/package.provided
echo -e 'FEATURES="-buildpkg -collision-detect -force-mirror -getbinpkg -protect-owned -sandbox -splitdebug -usersandbox"\nMAKEOPTS="--jobs 2"\nEMERGE_DEFAULT_OPTS="--jobs 2"\nUSE="-hardened -pam"' | sudo tee /build/reven/etc/portage/make.conf
sudo mkdir -p /build/reven/etc/portage/env /build/reven/etc/portage/profile
echo -e 'sys-libs/libxcrypt static-libs' | sudo tee /build/reven/etc/portage/profile/package.use
echo -e 'dev-util/cmake cmake.conf\ndev-lang/perl perl.conf' | sudo tee /build/reven/etc/portage/package.env
echo -e 'CXXFLAGS="-fexceptions -funwind-tables -fasynchronous-unwind-tables"\nCXXEXCEPTIONS=1' | sudo tee /build/reven/etc/portage/env/cmake.conf
echo -e 'EXTRA_ECONF="-Dbyteorder=1234"' | sudo tee /build/reven/etc/portage/env/perl.conf
emerge-${chromiumos_board} sys-apps/baselayout
echo -e "root:x:0:0:root:/root:/bin/bash\nportage:x:250:250:portage:/var/tmp/portage:/bin/false" | sudo tee /build/reven/etc/passwd
echo -e "portage::250:portage" | sudo tee /build/reven/etc/group
emerge-${chromiumos_board} acct-user/chronos acct-group/chronos acct-group/root app-admin/sudo app-alternatives/awk app-alternatives/gzip app-arch/cpio app-editors/nano app-misc/ca-certificates app-misc/jq app-misc/mime-types app-shells/bash chromeos-base/vboot_reference dev-build/libtool dev-build/meson dev-debug/strace dev-lang/go dev-lang/perl dev-lang/python dev-lang/python-exec dev-lang/python-exec-conf dev-libs/json-glib dev-libs/libtasn1 dev-python/ensurepip-pip dev-python/ensurepip-setuptools dev-python/ensurepip-wheels dev-python/installer dev-python/packaging dev-python/setuptools dev-python/wheel dev-util/cmake dev-util/ninja dev-util/pkgconf dev-vcs/git media-libs/libjpeg-turbo media-libs/libpng net-misc/curl net-misc/rsync net-misc/wget sys-apps/attr sys-apps/coreutils sys-apps/diffutils sys-apps/file sys-apps/findutils sys-apps/flashrom sys-apps/gawk sys-apps/grep sys-apps/install-xattr sys-apps/locale-gen sys-apps/mawk sys-apps/sandbox sys-apps/sed sys-apps/shadow sys-apps/texinfo sys-apps/util-linux sys-boot/efibootmgr sys-devel/autoconf sys-devel/autoconf-wrapper sys-devel/automake sys-devel/automake-wrapper sys-devel/binutils sys-devel/binutils-config sys-devel/bison sys-devel/flex sys-devel/gcc sys-devel/gcc-config sys-devel/gdb sys-devel/gnuconfig sys-devel/m4 sys-devel/make sys-devel/patch sys-fs/dosfstools sys-fs/ntfs3g sys-kernel/linux-headers sys-libs/libxcrypt sys-process/procps
sudo mkdir /build/reven/dev /build/reven/proc /build/reven/sys
sudo rm -r /build/reven/etc/make.conf* /build/reven/build /build/reven/packages /build/reven/sys-include /build/reven/usr/local /build/reven/tmp/portage
sudo sed -i '/features\/llvm/d' /mnt/host/source/src/third_party/chromiumos-overlay/profiles/default/linux/amd64/10.0/chromeos/parent
sudo sed -i -z 's@eapply "\${WORKDIR}/patch"@eapply "\${WORKDIR}/patch"\n\teapply "\${FILESDIR}/libcpp-enable-nls.patch"@g' /mnt/host/source/src/third_party/chromiumos-overlay/sys-devel/gcc/gcc-*.ebuild
sudo mkdir -p /build/reven/mnt/host/source/src/third_party
sudo cp -r /mnt/host/source/src/overlays /build/reven/mnt/host/source/src/
sudo cp -r /mnt/host/source/src/third_party/eclass-overlay /build/reven/mnt/host/source/src/third_party/
sudo cp -r /mnt/host/source/src/third_party/portage-stable /build/reven/mnt/host/source/src/third_party/
sudo cp -r /mnt/host/source/src/third_party/chromiumos-overlay /build/reven/mnt/host/source/src/third_party/
echo -e '[chromiumos]\nlocation = /mnt/host/source/src/third_party/chromiumos-overlay\n\n[portage-stable]\nlocation = /mnt/host/source/src/third_party/portage-stable\n\n[eclass-overlay]\nlocation = /mnt/host/source/src/third_party/eclass-overlay' | sudo tee /build/reven/etc/portage/repos.conf
echo -e 'CHOST="x86_64-cros-linux-gnu"\nFEATURES="-buildpkg -collision-detect -force-mirror -getbinpkg -protect-owned -sandbox -splitdebug -usersandbox"\nGENTOO_MIRRORS="https://storage.googleapis.com/chromeos-mirror/gentoo"\nPORTDIR="/var/cache"\nMAKEOPTS="--jobs 2"\nEMERGE_DEFAULT_OPTS="--jobs 2"\nUSE="-hardened -pam"' | sudo tee /build/reven/etc/portage/make.conf
echo -e 'sys-devel/gcc -multilib' | sudo tee /build/reven/etc/portage/profile/package.use.force
echo -e 'chronos ALL=(ALL) NOPASSWD: ALL' | sudo tee /build/reven/etc/sudoers.d/95_cros_base
CHROMIUMOS_BUILD
CHROOT_USER

mount -t proc none /home/temp/build_env/chromiumos/out/build/reven/proc
mount --bind -o ro /sys /home/temp/build_env/chromiumos/out/build/reven/sys
mount --make-slave /home/temp/build_env/chromiumos/out/build/reven/sys
mount --bind /dev /home/temp/build_env/chromiumos/out/build/reven/dev
mount --make-slave /home/temp/build_env/chromiumos/out/build/reven/dev
mount --bind /dev/pts /home/temp/build_env/chromiumos/out/build/reven/dev/pts
mount --make-slave /home/temp/build_env/chromiumos/out/build/reven/dev/pts
mount -t tmpfs -o mode=1777 none /home/temp/build_env/chromiumos/out/build/reven/dev/shm
mount -t tmpfs none /home/temp/build_env/chromiumos/out/build/reven/tmp

echo 'nameserver 8.8.8.8' > /home/temp/build_env/chromiumos/out/build/reven/etc/resolv.conf
cat >/home/temp/build_env/chromiumos/out/build/reven/init <<'FINALIZE'
#!/bin/bash

set -e

sudo emerge --nodeps sys-devel/binutils dev-libs/gmp dev-libs/mpfr dev-libs/mpc dev-libs/libffi sys-devel/gcc
sudo emerge --nodeps dev-build/libtool
sudo ln -sf gcc /usr/bin/cc
FINALIZE
chmod 0755 /home/temp/build_env/chromiumos/out/build/reven/init
chroot --userspec=1000:1000 /home/temp/build_env/chromiumos/out/build/reven /init
rm /home/temp/build_env/chromiumos/out/build/reven/etc/resolv.conf

umount /home/temp/build_env/chromiumos/out/build/reven/tmp
umount /home/temp/build_env/chromiumos/out/build/reven/dev/shm
umount /home/temp/build_env/chromiumos/out/build/reven/dev/pts
umount /home/temp/build_env/chromiumos/out/build/reven/dev
umount /home/temp/build_env/chromiumos/out/build/reven/sys
umount /home/temp/build_env/chromiumos/out/build/reven/proc
CHROOT_INIT
chmod 0755 ./chroot/init

cat >./chroot/bootstrap<<BOOTSTRAP
set -e
mount --bind ./chroot ./chroot
mount -t proc none ./chroot/proc
mount --bind -o ro /sys ./chroot/sys
mount --bind /dev ./chroot/dev
mount --bind /dev/pts ./chroot/dev/pts
mount -t tmpfs -o mode=1777 none ./chroot/dev/shm
mkdir ./chroot/old
cd chroot
pivot_root . ./old
PATH=/usr/sbin:/usr/bin:/sbin:/bin exec env -i chroot . bash -c "umount -l /old && /init"
BOOTSTRAP
chmod 0755 ./chroot/bootstrap
unshare --mount-proc --fork ./chroot/bootstrap

rm -f ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz
tar zcf ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz -C ./chroot/home/temp/build_env/chromiumos/out/build/reven .
chown ${SUDO_UID}:$(id -g ${SUDO_UID}) ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz

