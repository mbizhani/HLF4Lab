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

for orgmsp in Org1MSP Org2MSP; do
  sudo bin/configtxgen \
    -configPath "${NFS_DIR}"/configtx \
    -profile TwoOrgsChannel \
    -outputAnchorPeersUpdate "${INIT_DIR}/${orgmsp}anchors.tx" \
    -channelID "${CHANNEL_NAME}" \
    -asOrg ${orgmsp}
    echo "CreateAnchorPeer(${orgmsp}): $?"
done

helm install orderer helms/hlf-orderer \
  -f values/orderer.yaml \
  --set service.type="${SERVICE_TYPE}" \
  --set service.port="${ORDERER_PORT}" \
  --set hlfOrd.nfs.path="${NFS_DIR}" \
  --set hlfOrd.nfs.server="${NFS_SERVER}"
sleep 2
helm install peer0-org1 helms/hlf-peer \
  -f values/peer0-org1.yaml \
  --set service.type="${SERVICE_TYPE}" \
  --set service.port="$(peerPort 1)" \
  --set hlfPeer.nfs.path="${NFS_DIR}" \
  --set hlfPeer.nfs.server="${NFS_SERVER}"
sleep 2
helm install peer0-org2 helms/hlf-peer \
  -f values/peer0-org2.yaml \
  --set service.type="${SERVICE_TYPE}" \
  --set service.port="$(peerPort 2)" \
  --set hlfPeer.nfs.path="${NFS_DIR}" \
  --set hlfPeer.nfs.server="${NFS_SERVER}"
waitForChart "orderer"
waitForChart "peer0-org1"
waitForChart "peer0-org2"

PEER0_ORG1_POD="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance=peer0-org1 -o jsonpath="{.items[0].metadata.name}")"
PEER0_ORG2_POD="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance=peer0-org2 -o jsonpath="{.items[0].metadata.name}")"

kubectl -n "${NAMESPACE}" exec "${PEER0_ORG1_POD}" -c "${PEER_CTR}"  -- sh -c "
  export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}

  peer channel create \
    -o ${ORDERER_URL} \
    -c ${CHANNEL_NAME} \
    -f /hlf/init/${CHANNEL_NAME}.tx \
    --outputBlock /hlf/init/${CHANNEL_NAME}.block \
    --tls --cafile ${ORDERER_CA}
  echo \"*** Peer0.Org1 - Create: \$?\"

  sleep 3

  peer channel join -b /hlf/init/${CHANNEL_NAME}.block
  echo \"*** Peer0.Org1 - Join: \$?\"

  sleep 3

  peer channel update \
    -o ${ORDERER_URL} \
    -c ${CHANNEL_NAME} \
    -f /hlf/init/Org1MSPanchors.tx \
    --tls --cafile ${ORDERER_CA}
  echo \"*** Peer0.Org1 - Update: \$?\"
  "

sleep 3

kubectl -n "${NAMESPACE}" exec "${PEER0_ORG2_POD}" -c "${PEER_CTR}" -- sh -c "
  export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}

  peer channel join -b /hlf/init/${CHANNEL_NAME}.block
  echo \"*** Peer0.Org2 - Join: \$?\"

  sleep 3

  peer channel update \
    -o ${ORDERER_URL} \
    -c ${CHANNEL_NAME} \
    -f /hlf/init/Org2MSPanchors.tx \
    --tls --cafile ${ORDERER_CA}
  echo \"*** Peer0.Org2 - Update: \$?\"
  "

##
## $( [ $ORG == "1" ] && echo ${PEER_ORG1_PORT} || echo ${PEER_ORG2_PORT})

for org in 1 2; do
  PEER_PEM="${NFS_DIR}/organizations/peerOrganizations/org${org}.example.com/tlsca/tlsca.org${org}.example.com-cert.pem"
  CA_PEM="${NFS_DIR}/organizations/peerOrganizations/org${org}.example.com/ca/ca.org${org}.example.com-cert.pem"
  mkdir -p "${OUT_DIR}/organizations/peerOrganizations/org${org}.example.com"
  echo "$(yaml_ccp ${org} "$(peerPort $org)" "$(caPort $org)" "${PEER_PEM}" "${CA_PEM}")" > \
    "${OUT_DIR}/organizations/peerOrganizations/org${org}.example.com/connection-org${org}.yaml"
done

sudo cp -rf "${OUT_DIR}"/organizations "${NFS_DIR}"

## copy CA's pem for application to create 'wallet'
mkdir -p "${OUT_DIR}/ca"
for org in 1 2; do
  cp "${NFS_DIR}"/organizations/peerOrganizations/org${org}.example.com/ca/*.pem "${OUT_DIR}"/ca
done