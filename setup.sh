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

COMMANDS=$(cat <<EOF 
fdisk $DISK <<EOF  

g          
n          
p          
1          


w          
EOF
&&
{
  echo "http://dl-cdn.alpinelinux.org/alpine/$(cat /etc/alpine-release | cut -d '.' -f 1-2)/main"
  echo "http://dl-cdn.alpinelinux.org/alpine/$(cat /etc/alpine-release | cut -d '.' -f 1-2)/community"
} | tee /etc/apk/repositories &&

cat > /tmp/my_alpine_setup.conf << EOF
KEYMAPOPTS="us us"
HOSTNAMEOPTS="-n alpinelinux"
INTERFACESOPTS="auto"
TIMEZONEOPTS="-z UTC"
PROXYOPTS="none"
APKREPOSOPTS="-f"
SSHDOPTS="-c openssh"
NTPOPTS="-c chrony"
DISKOPTS="-m sys /mnt"  
LBUOPTS="none"
EOF 
&& 
setup-alpine -f /tmp/my_alpine_setup.conf &&

apk update &&

apk add sudo &&
apk add lvm2 &&

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

setup-alpine -f /tmp/my_alpine_setup.conf &&

sed -i 's/^features=.*/features="ata base ide scsi usb virtio lvm"/' /mnt/etc/mkinitfs/mkinitfs.conf &&
chroot /mnt mkinitfs &&

chroot /mnt apk add grub &&
chroot /mnt grub-install $DISK &&
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &&

umount -R /mnt 
)

tmux send-keys -t alpine-vm-base "$COMMANDS" C-m
