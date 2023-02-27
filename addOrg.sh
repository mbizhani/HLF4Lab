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

installPeerByChart ${ORG_ID}

###################
## Generate Config

# --- fetchChannelConfig() START
echo "--- Gen: 1"
fetchConfigBlock "${ADD_ORG_DIR}/01-config_block.pb"

echo "--- Gen: 2"
bin/configtxlator proto_decode \
  --type common.Block \
  --input  "${ADD_ORG_DIR}"/01-config_block.pb \
  --output "${ADD_ORG_DIR}"/02-config_block.json

echo "--- Gen: 3"
jq \
  .data.data[0].payload.data.config \
  "${ADD_ORG_DIR}"/02-config_block.json > "${ADD_ORG_DIR}"/03-config.json
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
echo "--- Gen: 6"
bin/configtxlator proto_encode \
  --type common.Config \
  --input "${ADD_ORG_DIR}"/05-modified_config.json \
  --output "${ADD_ORG_DIR}"/06-modified_config.pb

echo "--- Gen: 7"
bin/configtxlator proto_encode \
  --type common.Config \
  --input "${ADD_ORG_DIR}"/03-config.json \
  --output "${ADD_ORG_DIR}"/07-original_config.pb

bin/configtxlator compute_update \
  --channel_id "${CHANNEL_NAME}" \
  --original "${ADD_ORG_DIR}"/07-original_config.pb \
  --updated "${ADD_ORG_DIR}"/06-modified_config.pb \
  --output "${ADD_ORG_DIR}"/07-config_update.pb

echo "--- Gen: 8"
bin/configtxlator proto_decode \
  --type common.ConfigUpdate \
  --input "${ADD_ORG_DIR}"/07-config_update.pb \
  --output "${ADD_ORG_DIR}"/08-config_update.json

echo "--- Gen: 9"
echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_NAME}'", "type":2}},"data":{"config_update":'$(cat "${ADD_ORG_DIR}"/08-config_update.json)'}}}' | jq . > "${ADD_ORG_DIR}"/09-config_update_in_envelope.json

echo "--- Gen: 10"
bin/configtxlator proto_encode \
  --type common.Envelope \
 --input "${ADD_ORG_DIR}"/09-config_update_in_envelope.json \
 --output "${ADD_ORG_DIR}"/10-config_update_in_envelope.pb

# --- createConfigUpdate() END

sleep 1

sudo cp -rf "${ADD_ORG_DIR}" "${NFS_DIR}"/

# --- signConfigtxAsPeerOrg START
runInPeer 1 "
  peer channel signconfigtx -f /hlf/add-org${ORG_ID}/10-config_update_in_envelope.pb
"
# --- signConfigtxAsPeerOrg END

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