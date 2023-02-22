#!/bin/bash

source .env
source common.sh

INIT_DIR=${NFS_DIR}/init
sudo mkdir -p "${INIT_DIR}"

sudo mkdir -p "${NFS_DIR}"/configtx
eval "cat <<EOF
$(<network/configtx/configtx.yaml)
EOF" | sudo tee "${NFS_DIR}"/configtx/configtx.yaml

sudo bin/configtxgen \
  -configPath "${NFS_DIR}"/configtx \
  -profile TwoOrgsOrdererGenesis \
  -channelID system-channel \
  -outputBlock "${INIT_DIR}/genesis.block"
echo "GenesisBlock: $?"

sudo bin/configtxgen \
  -configPath "${NFS_DIR}"/configtx \
  -profile TwoOrgsChannel \
  -outputCreateChannelTx "${INIT_DIR}/${CHANNEL_NAME}.tx" \
  -channelID "${CHANNEL_NAME}"
echo "CreateChannelTx: $?"

helm install orderer helms/hlf-orderer \
  --set service.type="${SERVICE_TYPE}" \
  --set service.port="${ORDERER_PORT}" \
  --set image.repository="${REG_URL}/hyperledger/fabric-orderer" \
  --set hlfOrd.nfs.path="${NFS_DIR}" \
  --set hlfOrd.nfs.server="${NFS_SERVER}"
waitForChart "orderer"

sleep 2


for ORG_ID in 1 2; do
  sudo bin/configtxgen \
    -configPath "${NFS_DIR}"/configtx \
    -profile TwoOrgsChannel \
    -outputAnchorPeersUpdate "${INIT_DIR}/Org${ORG_ID}MSPAnchors.tx" \
    -channelID "${CHANNEL_NAME}" \
    -asOrg Org${ORG_ID}MSP
    echo "CreateAnchorPeer(Org${ORG_ID}MSP): $?"

  helm install peer0-org${ORG_ID} helms/hlf-peer \
    --set service.type="${SERVICE_TYPE}" \
    --set service.port="$(peerPort ${ORG_ID})" \
    --set hlfPeer.nfs.path="${NFS_DIR}" \
    --set hlfPeer.nfs.server="${NFS_SERVER}" \
    -f - <<EOF
hlfPeer:
  config:
    mspId: Org${ORG_ID}MSP
    fqdn: peer0.org${ORG_ID}.example.com
    cmpDir: organizations/peerOrganizations/org${ORG_ID}.example.com/peers/peer0.org${ORG_ID}.example.com
    adminMspDir: organizations/peerOrganizations/org${ORG_ID}.example.com/users/Admin@org${ORG_ID}.example.com/msp
  couchdb:
    image: ${REG_URL}/couchdb:3.1.1

image:
  repository: ${REG_URL}/hyperledger/fabric-peer
EOF

  waitForChart "peer0-org${ORG_ID}"
  sleep 2

  PEER0_ORG_POD="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance=peer0-org${ORG_ID} -o jsonpath="{.items[0].metadata.name}")"

  kubectl -n "${NAMESPACE}" exec "${PEER0_ORG_POD}" -c "${PEER_CTR}"  -- sh -c "
  export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}

  if [ '${ORG_ID}' == '1' ]; then
    peer channel create \
      -o ${ORDERER_URL} \
      -c ${CHANNEL_NAME} \
      -f /hlf/init/${CHANNEL_NAME}.tx \
      --outputBlock /hlf/init/${CHANNEL_NAME}.block \
      --tls --cafile ${ORDERER_CA}
    echo \"*** Peer0.Org${ORG_ID} - Create: \$?\"

    sleep 3
  fi

  peer channel join -b /hlf/init/${CHANNEL_NAME}.block
  echo \"*** Peer0.Org${ORG_ID} - Join: \$?\"

  sleep 3

  peer channel update \
    -o ${ORDERER_URL} \
    -c ${CHANNEL_NAME} \
    -f /hlf/init/Org${ORG_ID}MSPAnchors.tx \
    --tls --cafile ${ORDERER_CA}
  echo \"*** Peer0.Org${ORG_ID} - Update: \$?\"
  "
done