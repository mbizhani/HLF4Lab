#!/bin/bash

source .env
source common.sh

ORG_ID="3"

mkdir -p "${OUT_DIR}"/fabric-ca/org${ORG_ID}
eval "cat <<EOF
$(<network/organizations/fabric-ca-server-config-ORG.yaml)
EOF" > "${OUT_DIR}"/fabric-ca/org${ORG_ID}/fabric-ca-server-config.yaml

sudo cp -rf "${OUT_DIR}"/fabric-ca "${NFS_DIR}"

installCA4Org ${ORG_ID}

