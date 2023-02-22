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


ADD_ORG_DIR="${NFS_DIR}/add-org"

sudo rm -rf "${ADD_ORG_DIR}" && mkdir "${ADD_ORG_DIR}"
eval "cat <<EOF
$(<network/configtx-org/configtx.yaml)
EOF" | sudo tee "${ADD_ORG_DIR}"/configtx.yaml

sudo bin/configtxgen \
  -configPath "${ADD_ORG_DIR}" \
  -printOrg Org${ORG_ID}MSP | sudo tee "${ADD_ORG_DIR}"/01-org${ORG_ID}.json

##
installPeerByChart ${ORG_ID}

runInPeer 1 "
  peer channel fetch config /hlf/add-org/02-config_block.pb \
    -o ${ORDERER_URL} \
    --tls --cafile ${ORDERER_CA} \
    -c ${CHANNEL_NAME}
"

sudo -s <<EOF

echo "--- Gen: 3"
bin/configtxlator proto_decode \
  --type common.Block \
  --input  "${ADD_ORG_DIR}"/02-config_block.pb \
  --output "${ADD_ORG_DIR}"/03-config_block.json

echo "--- Gen: 4"
jq \
  .data.data[0].payload.data.config \
  "${ADD_ORG_DIR}"/03-config_block.json > "${ADD_ORG_DIR}"/04-config.json

echo "--- Gen: 5"
jq \
  -s ".[0] * {\"channel_group\":{\"groups\":{\"Application\":{\"groups\": {\"Org${ORG_ID}MSP\":.[1]}}}}}" \
  "${ADD_ORG_DIR}"/04-config.json \
  "${ADD_ORG_DIR}"/01-org${ORG_ID}.json > "${ADD_ORG_DIR}"/05-modified_config.json

echo "--- Gen: 6"
bin/configtxlator proto_encode \
  --type common.Config \
  --input "${ADD_ORG_DIR}"/05-modified_config.json \
  --output "${ADD_ORG_DIR}"/06-modified_config.pb

echo "--- Gen: 7"
bin/configtxlator compute_update \
  --channel_id "${CHANNEL_NAME}" \
  --original "${ADD_ORG_DIR}"/02-config_block.pb \
  --updated "${ADD_ORG_DIR}"/06-modified_config.pb \
  --output "${ADD_ORG_DIR}"/07-config_update.pb

echo "--- Gen: 8"
bin/configtxlator proto_decode \
  --type common.ConfigUpdate \
  --input "${ADD_ORG_DIR}"/07-config_update.pb \
  --output "${ADD_ORG_DIR}"/08-config_update.json

echo "--- Gen: 9"
echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_NAME}'", "type":2}},"data":{"config_update":'\$(cat "${ADD_ORG_DIR}"/08-config_update.json)'}}}' | jq . > "${ADD_ORG_DIR}"/09-config_update_in_envelope.json

echo "--- Gen: 10"
bin/configtxlator proto_encode \
  --type common.Envelope \
 --input "${ADD_ORG_DIR}"/09-config_update_in_envelope.json \
 --output "${ADD_ORG_DIR}"/10-org${ORG_ID}_update_in_envelope.pb

EOF

runInPeer 1 "
  peer channel signconfigtx -f /hlf/add-org/10-org${ORG_ID}_update_in_envelope.pb
"

runInPeer 2 "
  peer channel update \
    -o ${ORDERER_URL} \
    --tls --cafile ${ORDERER_CA} \
    -c ${CHANNEL_NAME} \
    -f /hlf/add-org/10-org${ORG_ID}_update_in_envelope.pb
"