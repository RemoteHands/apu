#!/bin/sh
export HOSTNAME=$(cat /etc/hostname)
SCRIPT_PATH=$(readlink -f "$0")
export BASEDIR=$(dirname "$SCRIPT_PATH")
export PATH_PREFIX=$1
. $BASEDIR/config

if [ "$PATH_PREFIX" = "" ]; then
    DRY_RUN=0
    echo "Production 🚨"
    printf "Press Enter to confirm or Strg + C to cancel"
    read ok
else
    echo "Dry-Run 🚨"
    DRY_RUN=1
fi

if [ $DRY_RUN -eq 0 ]; then
    apt-get install -y libqmi-utils udhcpc bird rsync ifplugd socat openvpn
fi

# Static Files
if [ $DRY_RUN -eq 0 ]; then
    rsync -av --exclude "*.template" "${BASEDIR}/static/" "${PATH_PREFIX:-/}"
fi

# Templates
for CURRENT_FILE in $(find "${BASEDIR}/etc" -type f -printf '/etc/%P\n'); do
    TARGET_FILE="${PATH_PREFIX}${CURRENT_FILE%.template}"
    TARGET_DIR=$(dirname "$TARGET_FILE")
    echo "Writing $TARGET_FILE from template"
    mkdir -p "$TARGET_DIR"
    envsubst '$VPN_PRIMARY $VPN_SECONDARY $OPENVPN_PORT $OPENVPN_CLIENT_NAME $NIC_MOBILE_A $NIC_MOBILE_B $NIC_WIRED $NIC_VPN_PRIMARY $NIC_VPN_SECONDARY $BIRD_LOCAL_IP $BIRD_REMOTE_IP $APN' \
      < "${BASEDIR}${CURRENT_FILE}" \
      > "${TARGET_FILE}"
done

if [ ! -d "${PATH_PREFIX}/etc/openvpn/client" ]; then
	echo "OpenVPN uninitialized. Configuring client credentials keys/ directory"
	# initial OpenVPN configuration
	mkdir -p "${PATH_PREFIX}/etc/openvpn/client/"
	cp "${BASEDIR}/credentials/${OPENVPN_CLIENT_NAME}.key" "${PATH_PREFIX}/etc/openvpn/client/"
	cp "${BASEDIR}/credentials/${OPENVPN_CLIENT_NAME}.crt" "${PATH_PREFIX}/etc/openvpn/client/"
	cp "${BASEDIR}/credentials/ta.key" "${PATH_PREFIX}/etc/openvpn/client/"
	cp "${BASEDIR}/credentials/ca.crt" "${PATH_PREFIX}/etc/openvpn/client/"

	chown -R root:root "${PATH_PREFIX}/etc/openvpn/client"
	chmod -R 550 "${PATH_PREFIX}/etc/openvpn/client"
fi

if [ $DRY_RUN -eq 0 ]; then
    # configure and run services
    systemctl disable openvpn@client-primary
    systemctl disable openvpn@client-secondary

    systemctl enable bird
    systemctl restart bird

    systemctl disable bird6
    systemctl stop bird6
fi    
