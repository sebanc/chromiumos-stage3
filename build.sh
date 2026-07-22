#!/usr/bin/env bash

set -e

chromiumos_short_version=R150

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

cat >./reposync <<CHROOT_USER
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
echo -e 'sys-libs/libxcrypt static-libs' | sudo tee /etc/portage/profile/package.use
sudo emerge dev-libs/json-glib sys-boot/efibootmgr sys-fs/ntfs3g sys-libs/libxcrypt
qlist -I 'target-sdk-' | xargs qlist -I 'target-chromium-' | xargs qlist -I 'cross-' | xargs qlist -I 'app-emulation/qemu' | xargs qlist -I 'dev-util/intel_clc' | xargs qlist -I 'chromeos-base/pigweed-utils' | xargs qlist -I 'dev-util/hdctools' | xargs qlist -I 'dev-util/cros-hpt' | xargs qlist -I 'dev-util/test-services' | xargs qlist -I 'sys-devel/dex2oatds' | xargs qlist -I 'sys-boot/grub' | xargs qlist -I 'sys-devel/dex2oatds' | xargs qlist -I 'dev-lang/rust-bootstrap' | xargs qlist -I 'dev-go/u-root' | xargs sudo emerge --depclean --verbose
qlist -I 'sys-devel/llvm' | xargs sudo emerge --unmerge
sudo rm -rf /usr/lib64/cros_rust_registry /usr/share/doc
CHROMIUMOS_BUILD
CHROOT_USER
chmod 0755 ./reposync
sudo -u temp ./reposync

sudo tar --exclude='mnt' --exclude='opt' -zcf ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz -C /home/temp/build_env/chromiumos/chroot .

#bash
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
mv ./chroot/home/temp/chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz
chmod 0644 ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz
chown ${SUDO_UID}:$(id -g ${SUDO_UID}) ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz
ln -s ./chromiumos_stage3_$(echo ${chromiumos_short_version} | tr '[A-Z]' '[a-z]')_$(date +"%Y%m%d").tar.gz ./chromiumos_stage3.tar.gz

