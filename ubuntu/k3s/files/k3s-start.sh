#!/bin/bash +x

K3S_NODE_NAME=$(hostname)

export K3S_NODE_NAME
export K3S_TOKEN

if [ -n "$K3S_CMD" == "server" ] || [ -n "$K3S_CMD" == "agent" ]; then
    echo "Unsupported value for K3S_CMD: $K3S_CMD (supported: server, agent)";
    exit 1;
fi

if [ "$K3S_CMD" == "agent" ]; then
    if [ -z "$K3S_TOKEN" ]; then
        # If the token is not set manually, try to fetch the token from control plane server
        RETRIES=300
        while [ $RETRIES -gt 0 ]; do
            if ! nc -z "leader" 6443; then
                echo "Waiting for K3s API..."
                sleep 1
                RETRIES=$((RETRIES-1))
                continue
            fi

            K3S_TOKEN=$(wget -nv -q -O - --retry-connrefused --tries=0 --waitretry 5 http://leader:1337/join/$K3S_NODE_NAME)
            if [ -n "${K3S_TOKEN}" ]; then
                export K3S_TOKEN
                break
            fi

            echo "Waiting for token to be available..."
            sleep 1
            RETRIES=$((RETRIES-1))
        done
    fi

    K3S_CONTROL_PLANE_IP=$(host "leader" | grep ' has address ' | awk '{print $NF}')
    K3S_URL="https://${K3S_CONTROL_PLANE_IP}:6443/"
    export K3S_URL
else
    K3S_CONTROL_PLANE_IP=$(host "leader" | grep ' has address ' | awk '{print $NF}')
    INSTALL_K3S_EXEC="${INSTALL_K3S_EXEC} --tls-san ${K3S_CONTROL_PLANE_IP}"
    #systemctl enable kubectl-proxy
    #systemctl start kubectl-proxy &
    #systemctl start kube-dashboard &
fi

/usr/local/bin/k3s "$K3S_CMD" ${INSTALL_K3S_EXEC}