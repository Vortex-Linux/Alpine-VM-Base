#!/bin/bash

DISK="/dev/sda"

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
apk add sudo xorg-server xpra lvm2 && 

fdisk $DISK <<PARTITION

g          
n          
p          
1          


w          
PARTITION
 
pvcreate ${DISK}1 && 
vgcreate my_vg ${DISK}1 &&

lvcreate --size 100P --thinpool my_thinpool my_vg &&

lvcreate --thin --name my_root_lv --virtualsize 100P my_vg/my_thinpool && 
lvcreate --thin --name my_boot_lv --virtualsize 100P my_vg/my_thinpool &&

mkfs.ext4 /dev/my_vg/my_root_lv &&
mkfs.ext4 /dev/my_vg/my_boot_lv &&

mount /dev/my_vg/my_root_lv /mnt &&
mkdir /mnt/boot &&
mount /dev/my_vg/my_boot_lv /mnt/boot &&

sed -i 's/^features=.*/features="ata base ide scsi usb virtio lvm"/' /mnt/etc/mkinitfs/mkinitfs.conf &&
chroot /mnt mkinitfs &&

chroot /mnt apk add grub &&
chroot /mnt grub-install $DISK &&
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
EOF
)

tmux send-keys -t alpine-vm-base "$COMMANDS" C-m
