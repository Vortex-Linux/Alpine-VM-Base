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

setup-ntp -c chrony
EOF
)

tmux send-keys -t alpine-vm-base "$COMMANDS" C-m
