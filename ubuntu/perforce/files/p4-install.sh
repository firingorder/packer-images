#!/bin/bash
set -ex

export HOME=/root

wget -qO - https://package.perforce.com/perforce.pubkey | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/perforce.list
deb http://package.perforce.com/apt/ubuntu focal release
EOF

IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
echo $IP > /etc/oldip

hostname perforce
hostnamectl set-hostname perforce
sed -i 's/localhost$/localhost perforce/' /etc/hosts

ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

echo "waiting 180 seconds for cloud-init to update /etc/apt/sources.list"
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo waiting ...; sleep 1; done'

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install \
    git curl wget \
    apt-transport-https \
    ca-certificates \
    curl \
    ntp \
    software-properties-common \
    conntrack \
    jq vim nano emacs joe \
    inotify-tools \
    socat make \
    unzip \
    tmux htop \
    sudo fail2ban \
    bash-completion \
    dnsutils \
    iputils-ping \
    stow \
    ansible \
    helix-p4d
