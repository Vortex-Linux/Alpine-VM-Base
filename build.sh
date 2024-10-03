#!/bin/bash

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
XML_FILE="/tmp/alpine-vm-base.xml"

LATEST_IMAGE=$(lynx -dump -listonly -nonumbers https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64 | grep 'virt' | grep '.iso' | grep -v '\.sha\|\.asc' | sort -V | tail -n 1)

ship --vm delete alpine-vm-base 

echo n | ship --vm create alpine-vm-base --source "$LATEST_IMAGE"

sed -i '/<\/devices>/i \
  <console type="pty">\
    <target type="virtio"/>\
  </console>\
  <serial type="pty">\
    <target port="0"/>\
  </serial>' "$XML_FILE"

virsh -c qemu:///system undefine alpine-vm-base
virsh -c qemu:///system define "$XML_FILE"

ship --vm start alpine-vm-base 

#sleep 10 

#./setup.sh
./view_vm.sh

