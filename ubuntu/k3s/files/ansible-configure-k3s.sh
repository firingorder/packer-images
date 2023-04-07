#!/bin/sh

# install ansible requirements
ansible-pull -U https://luke-james:$GITHUB_ACCESS_TOKEN@github.com/firingorder/ansible-boxconf.git \
    --accept-host-key \
    --only-if-changed \
    --inventory /usr/local/bin/ansible/hosts.ini \
    -d /usr/local/bin/ansible/boxconf \
    /usr/local/bin/ansible/boxconf/k3s.yml

# apply k3s configuration
ansible-pull -U https://luke-james:$GITHUB_ACCESS_TOKEN@github.com/firingorder/ansible-runbooks.git \
    --accept-host-key \
    --only-if-changed \
    --inventory /usr/local/bin/ansible/hosts.ini \
    -d /usr/local/bin/ansible/runbooks \
    /usr/local/bin/ansible/runbooks/k3s.yml
