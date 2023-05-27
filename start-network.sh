#!/bin/bash

source .env
source common.sh

INIT_DIR=${OUT_DIR}/init
mkdir -p "${INIT_DIR}"

mkdir -p "${OUT_DIR}"/configtx
eval "cat <<EOF
$(<network/configtx/configtx.yaml)
EOF" > "${OUT_DIR}"/configtx/configtx.yaml

bin/configtxgen \
  -configPath "${OUT_DIR}"/configtx \
  -profile TwoOrgsOrdererGenesis \
  -channelID system-channel \
  -outputBlock "${INIT_DIR}/genesis.block"
echo "GenesisBlock: $?"

bin/configtxgen \
  -configPath "${OUT_DIR}"/configtx \
  -profile TwoOrgsChannel \
  -channelID "${CHANNEL_NAME}" \
  -outputCreateChannelTx "${INIT_DIR}/${CHANNEL_NAME}.tx"
echo "CreateChannelTx: $?"

for ORG_ID in 1 2; do
  bin/configtxgen \
    -configPath "${OUT_DIR}"/configtx \
    -profile TwoOrgsChannel \
    -channelID "${CHANNEL_NAME}" \
    -asOrg Org${ORG_ID}MSP \
    -outputAnchorPeersUpdate "${INIT_DIR}/Org${ORG_ID}MSPAnchors.tx"
    echo "CreateAnchorPeer(Org${ORG_ID}MSP): $?"
done

out2nfs init

## START ORDERER
helm install orderer helms/hlf-orderer \
  --set service.type="${SERVICE_TYPE}" \
  --set service.port="${ORDERER_PORT}" \
  --set image.repository="${REG_URL}/hyperledger/fabric-orderer" \
  --set hlfOrd.nfs.path="${NFS_DIR}" \
  --set hlfOrd.nfs.server="${NFS_SERVER}"
waitForChart "orderer"

sleep 2

## START PEERS
for ORG_ID in 1 2; do
  installPeerByChart ${ORG_ID}
  sleep 2

  runInPeer ${ORG_ID} "
  if [ '${ORG_ID}' == '1' ]; then
    peer channel create \
      -o ${ORDERER_URL} \
      --tls --cafile ${ORDERER_CA} \
      -c ${CHANNEL_NAME} \
      -f /hlf/init/${CHANNEL_NAME}.tx \
      --outputBlock /hlf/init/${CHANNEL_NAME}.block

    echo \"*** Peer0.Org${ORG_ID} - Create: \$?\"
    sleep 3
  fi

  peer channel join -b /hlf/init/${CHANNEL_NAME}.block
  echo \"*** Peer0.Org${ORG_ID} - Join: \$?\"
  sleep 3

  peer channel update \
    -o ${ORDERER_URL} \
    --tls --cafile ${ORDERER_CA} \
    -c ${CHANNEL_NAME} \
    -f /hlf/init/Org${ORG_ID}MSPAnchors.tx

  echo \"*** Peer0.Org${ORG_ID} - Update: \$?\"
  "
done