#!/bin/bash

source .env
source common.sh

ORG_ID="3"
ADD_ORG_DIR="${OUT_DIR}/add-org${ORG_ID}"
mkdir "${ADD_ORG_DIR}"

############
## Start CA
mkdir -p "${OUT_DIR}"/fabric-ca/org${ORG_ID}
eval "cat <<EOF
$(<network/organizations/fabric-ca-server-config-ORG.yaml)
EOF" > "${OUT_DIR}"/fabric-ca/org${ORG_ID}/fabric-ca-server-config.yaml

sudo cp -rf "${OUT_DIR}"/fabric-ca "${NFS_DIR}"

installCA4Org ${ORG_ID}

###################
## Generate Config

# --- fetchChannelConfig() START
echo "--- Gen: 1 & 2 & 3"
fetchChannelConfigBlock "${ADD_ORG_DIR}" "01-config_block.pb" "02-config_block.json" "03-config.json"
# --- fetchChannelConfig() END

echo "--- Gen: 4"
eval "cat <<EOF
$(<network/configtx-org/configtx.yaml)
EOF" > "${ADD_ORG_DIR}"/configtx.yaml

sudo bin/configtxgen \
  -configPath "${ADD_ORG_DIR}" \
  -printOrg Org${ORG_ID}MSP > "${ADD_ORG_DIR}"/04-org.json

echo "--- Gen: 5"
jq \
  -s ".[0] * {\"channel_group\":{\"groups\":{\"Application\":{\"groups\": {\"Org${ORG_ID}MSP\":.[1]}}}}}" \
  "${ADD_ORG_DIR}"/03-config.json \
  "${ADD_ORG_DIR}"/04-org.json > "${ADD_ORG_DIR}"/05-modified_config.json

# --- createConfigUpdate() START
createUpdateConfigBlock "${ADD_ORG_DIR}" "03-config.json" "05-modified_config.json" 6
# --- createConfigUpdate() END

sleep 1

sudo cp -rf "${ADD_ORG_DIR}" "${NFS_DIR}"/

# --- signConfigtxAsPeerOrg START
runInPeer 1 "
  peer channel signconfigtx -f /hlf/add-org${ORG_ID}/10-config_update_in_envelope.pb
"
# --- signConfigtxAsPeerOrg END

# updateChannelConfig.sh
runInPeer 2 "
  peer channel update \
    -o ${ORDERER_URL} \
    --tls --cafile ${ORDERER_CA} \
    -c ${CHANNEL_NAME} \
    -f /hlf/add-org${ORG_ID}/10-config_update_in_envelope.pb
  "

sleep 2

################
## Join Channel

installPeerByChart ${ORG_ID}

# joinChannel.sh & joinChannel()
runInPeer ${ORG_ID} "
  mv /hlf/init/${CHANNEL_NAME}.block /hlf/init/B4_${ORG_ID}_${CHANNEL_NAME}.block

  peer channel fetch 0 /hlf/init/${CHANNEL_NAME}.block \
    -o ${ORDERER_URL} \
    --tls --cafile ${ORDERER_CA} \
    -c ${CHANNEL_NAME}

  sleep 3

  peer channel join -b /hlf/init/${CHANNEL_NAME}.block
  echo \"*** Peer0.Org${ORG_ID} - Join: \$?\"
  sleep 3
  "

# --- createAnchorPeerUpdate() START
echo "--- Gen: 11 & 12 & 13"
fetchChannelConfigBlock "${ADD_ORG_DIR}" "11-config_block.pb" "12-config_block.json" "13-config.json"

echo "--- Gen: 14"
CORE_PEER_LOCALMSPID="Org${ORG_ID}MSP"
HOST="peer0.org${ORG_ID}.example.com"
PORT="$(peerPort "${ORG_ID}")"
jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'${HOST}'","port": '${PORT}'}]},"version": "0"}}' \
  "${ADD_ORG_DIR}"/13-config.json > "${ADD_ORG_DIR}"/14-modified_config.json

createUpdateConfigBlock "${ADD_ORG_DIR}" "13-config.json" "14-modified_config.json" 15
# --- createAnchorPeerUpdate() END

sleep 2
sudo cp -rf "${ADD_ORG_DIR}" "${NFS_DIR}"/

runInPeer ${ORG_ID} "
  peer channel update \
    -o ${ORDERER_URL} \
    --tls --cafile ${ORDERER_CA} \
    -c ${CHANNEL_NAME} \
    -f /hlf/add-org${ORG_ID}/19-config_update_in_envelope.pb
  "