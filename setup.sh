#!/bin/bash

DISK="/dev/vda"

COMMANDS=$(cat <<'EOF'
root
EOF
)

while IFS= read -r command; do
    if [[ -n "$command" ]]; then
        tmux send-keys -t alpine-vm-base "$command" C-m
        sleep 1
    fi
done <<< "$COMMANDS"

COMMANDS=$(cat << EOF
setup-keymap us us &&

setup-hostname -n alpinelinux &&

setup-interfaces &&

rc-service networking --quiet start &&

echo "root:alpine" | chpasswd &&

rc-service hostname --quiet restart &&

rc-update add networking boot &&
rc-update add seedrng boot &&
rc-update add acpid default &&
rc-update add crond default &&

setup-apkrepos -f &&

adduser -D alpine && 
echo "alpine:alpine" | chpasswd &&

setup-sshd -c openssh &&

setup-ntp -c chrony && 

sed -i '/^#http:\/\/mirror.jingk.ai\/alpine\/v3.20\/community/s/^#//' /etc/apk/repositories && 
apk update && 
apk add sudo xorg-server xpra lvm2 lvm2-dmeventd thin-provisioning-tools e2fsprogs && 

pvcreate $DISK &&
vgcreate alpine-vg $DISK && 
lvcreate -L 2045G --thinpool thin-pool --chunksize 128K alpine-vg && 
lvcreate -V 1023G --thin alpine-vg/thin-pool -n root && 
lvcreate -V 1022G --thin alpine-vg/thin-pool -n home && 

mkfs.ext4 /dev/alpine-vg/root &&
mkfs.ext4 /dev/alpine-vg/home && 

mount /dev/alpine-vg/root /mnt &&
mkdir /mnt/home &&
mount /dev/alpine-vg/home /mnt/home &&

mount -t proc none /mnt/proc &&
mount -o bind /dev /mnt/dev &&
mount -o bind /sys /mnt/sys &&
chroot /mnt /bin/sh << CHROOT
echo "hi"
CHROOT &&

apk add grub-bios &&
grub-install --root-directory=/mnt /dev/vda &&
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &&

umount /mnt/sys &&
umount /mnt/dev &&
umount /mnt/proc &&
umount /mnt/home &&
umount /mnt
EOF
)

tmux send-keys -t alpine-vm-base "$COMMANDS" C-m
