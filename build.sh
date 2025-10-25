#!/usr/bin/env bash

chromeos_short_version=R141

rm -rf ./chroot
mkdir ./chroot

if [ ! -f gentoo-stage3-amd64-openrc.tar.xz ]; then
	stage3="$(curl --progress-bar --connect-timeout 60 --retry 10 --retry-delay 1 -L -f https://gentoo.osuosl.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt | grep 'stage3' | cut -d' ' -f1)"
	echo "Downloading Gentoo stage 3"
	curl --progress-bar --connect-timeout 60 --retry 10 --retry-delay 1 -L -f https://gentoo.osuosl.org/releases/amd64/autobuilds/"${stage3}" -o ./gentoo-stage3-amd64-openrc.tar.xz
fi
tar xf ./gentoo-stage3-amd64-openrc.tar.xz -C ./chroot

echo 'nameserver 1.1.1.1' > ./chroot/etc/resolv.conf

mount -t proc none ./chroot/proc
mount --bind -o ro /sys ./chroot/sys
mount --make-slave ./chroot/sys
mount --bind /dev ./chroot/dev
mount --make-slave ./chroot/dev
mount --bind /dev/pts ./chroot/dev/pts
mount --make-slave ./chroot/dev/pts
mount -t tmpfs -o mode=1777 none ./chroot/dev/shm

cp ./stage1 ./chroot/init
cp ./stage2 ./chroot/stage2
env -i PATH=/usr/sbin:/usr/bin:sbin:/bin chromeos_short_version=$chromeos_short_version chroot ./chroot /init

for ROOT in $(find /proc/*/root 2>/dev/null); do
	LINK="$(readlink -f ${ROOT})"
	if echo "${LINK}" | grep -q $(realpath ./chroot); then
		PID=$(basename $(dirname "${ROOT}"))
		kill -STOP ${PID} 2>/dev/null
	fi
done
sleep 2
for ROOT in $(find /proc/*/root 2>/dev/null); do
	LINK="$(readlink -f ${ROOT})"
	if echo "${LINK}" | grep -q $(realpath ./chroot); then
		PID=$(basename $(dirname "${ROOT}"))
		kill -9 ${PID} 2>/dev/null
	fi
done
sleep 5

if mountpoint -q ./chroot/bootstrap/dev/shm; then umount ./chroot/bootstrap/dev/shm; fi
if mountpoint -q ./chroot/bootstrap/dev/pts; then umount ./chroot/bootstrap/dev/pts; fi
if mountpoint -q ./chroot/bootstrap/dev; then umount ./chroot/bootstrap/dev; fi
if mountpoint -q ./chroot/bootstrap/sys; then umount ./chroot/bootstrap/sys; fi
if mountpoint -q ./chroot/bootstrap/proc; then umount ./chroot/bootstrap/proc; fi
if mountpoint -q ./chroot/dev/shm; then umount ./chroot/dev/shm; fi
if mountpoint -q ./chroot/dev/pts; then umount ./chroot/dev/pts; fi
if mountpoint -q ./chroot/dev; then umount ./chroot/dev; fi
if mountpoint -q ./chroot/sys; then umount ./chroot/sys; fi
if mountpoint -q ./chroot/proc; then umount ./chroot/proc; fi

if [ -f ./chroot/bootstrap/.finished ]; then
	rm -f ./chroot/bootstrap/.finished ./chromiumos_stage3.tar.gz ./chromiumos_stage3_"$(date +"%Y%m%d")".tar.gz
	tar zcf ./chromiumos_stage3_"$(date +"%Y%m%d")".tar.gz -C ./chroot/bootstrap .
	ln -s ./chromiumos_stage3_"$(date +"%Y%m%d")".tar.gz ./chromiumos_stage3.tar.gz
	chown ${SUDO_UID}:$(id -g ${SUDO_UID}) ./chromiumos_stage3.tar.gz ./chromiumos_stage3_"$(date +"%Y%m%d")".tar.gz
fi

