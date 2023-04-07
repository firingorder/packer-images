#!/bin/bash

# install ansible requirements
ansible-pull -U https://luke-james:$GITHUB_ACCESS_TOKEN@github.com/firingorder/ansible-boxconf.git \
    --accept-host-key \
    --only-if-changed \
    --inventory /usr/local.bin/ansible/hosts.ini \
    -d /usr/local/bin/ansible/boxconf \
    /usr/local/bin/ansible/boxconf/perforce.yml

# apply p4 configuration
ansible-pull -U https://luke-james:$GITHUB_ACCESS_TOKEN@github.com/firingorder/ansible-runbooks.git \
    --accept-host-key \
    --only-if-changed \
    --inventory /usr/local/bin/ansible/hosts.ini \
    -d /usr/local/bin/ansible/runbooks \
    /usr/local/bin/ansible/runbooks/perforce.yml
