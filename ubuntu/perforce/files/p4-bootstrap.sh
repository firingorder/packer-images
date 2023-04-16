#!/bin/bash
set -ex

ANSIBLE_DIR=/usr/local/bin/ansible

INSTALLER_DIR=/usr/local/bin/sdp
INSTALLER_SCRIPT=$INSTALLER_DIR/reset_sdp.sh
INSTALLER_SETTINGS_FILE=$INSTALLER_DIR/sdp.cfg
INSTALLER_LOG_FILE=/var/log/sdp-reset.log

echo "waiting 600 seconds for cloud-init to finish"
timeout 600 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo waiting ...; sleep 1; done'

# install sdp
if [ -f "$INSTALLER_DIR/reset_sdp.sh" ]; then
    echo "Installing Perforce SDP from: $INSTALLER_DIR"
    bash $INSTALLER_SCRIPT -c $INSTALLER_SETTINGS_FILE -fast 2>&1 | tee $INSTALLER_LOG_FILE
    sudo -u perforce bash -c 'source /p4/common/bin/p4_vars ${INSTANCE};echo $(p4d -Gf) | if [ -n $P4SSLDIR ]; then sed -r "s/^Fingerprint: //" > $P4SSLDIR/fingerprint.txt; fi'
fi

# configure ansible controller
if [ -d "$ANSIBLE_DIR" ]; then
    chown -R p4admin:perforce $ANSIBLE_DIR
    systemctl enable --now ansible-configure-helix.timer
fi