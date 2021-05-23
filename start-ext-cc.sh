#!/bin/bash

function installCC() {
  PEER_POD=$1
  kubectl -n ${NAMESPACE} exec "${PEER_POD}" -c hlf-peer -- sh -c "
    export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}

    peer lifecycle chaincode \
      install /hlf/chaincode/${CC_NAME}.tar.gz
    echo \"Install: \$?\"
   "
}

function approveForMyOrg() {
  PEER_POD=$1
  kubectl -n ${NAMESPACE} exec "${PEER_POD}" -c hlf-peer -- sh -c "
    export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}

    peer lifecycle chaincode approveformyorg \
      -o ${ORDERER_URL} \
      --tls --cafile ${ORDERER_CA} \
      --channelID ${CHANNEL_NAME} \
      --name ${CC_NAME} \
      --version ${CC_VERSION} \
      --package-id ${PACKAGE_ID} \
      --sequence ${CC_SEQUENCE} ${CC_INIT_REQUIRED}

    echo \"Approve for My Org: \$?\"
    "
}

function commitCC() {
  PEER_POD=$1
  kubectl -n ${NAMESPACE} exec "${PEER_POD}" -c hlf-peer -- sh -c "
    export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}

    peer lifecycle chaincode commit \
      -o ${ORDERER_URL} \
      --tls --cafile ${ORDERER_CA} \
      --channelID ${CHANNEL_NAME} \
      --name ${CC_NAME} \
      --version ${CC_VERSION} \
      --peerAddresses peer0.org1.example.com:7051 \
      --tlsRootCertFiles /hlf/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
      --peerAddresses peer0.org2.example.com:7051 \
      --tlsRootCertFiles /hlf/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
      --sequence ${CC_SEQUENCE} ${CC_INIT_REQUIRED}

    echo \"Commit CC: \$?\"
  "
}

#function checkCommitReadiness() {
#  PEER_POD="$1"
#  PARAM1="$2"
#
#  kubectl exec "${PEER_POD}" -c hlf-peer -- sh -c "
#    export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}
#
#    CNT=0
#    while [ \${CNT} -eq 0 ]; do
#      echo \"Check Commit Readiness: \${CNT} - ${PEER_POD} - ${PARAM1} ...\"
#
#      peer lifecycle chaincode checkcommitreadiness \
#        --channelID ${CHANNEL_NAME} \
#        --name ${CC_NAME} \
#        --version ${CC_VERSION} \
#        --sequence ${CC_SEQUENCE} ${CC_INIT_REQUIRED} --output json >&log.txt
#
#      cat log.txt
#      sleep 2
#      CNT=\$(grep '${PARAM1}' log.txt -c)
#    done
#  "
#}

#function queryCommitted() {
#  PEER_POD="$1"
#  kubectl exec "${PEER_POD}" -c hlf-peer -- sh -c "
#    export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}
#
#    peer lifecycle chaincode querycommitted \
#      --channelID ${CHANNEL_NAME} \
#      --name ${CC_NAME}
#
#    echo \"Query Committed: \$?\"
#  "
#}

function invokeInitCC() {
  PEER_POD="$1"
  FCN_CALL='{"function":"'${CC_INIT_FCN}'","Args":[]}'

  #TIP: just needs one of the peers!!!
  kubectl -n ${NAMESPACE} exec "${PEER_POD}" -c hlf-peer -- sh -c "
    export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}

    peer chaincode invoke \
      -o ${ORDERER_URL} \
      --tls --cafile ${ORDERER_CA} \
      --channelID ${CHANNEL_NAME} \
      --name ${CC_NAME} \
      --peerAddresses peer0.org1.example.com:7051 \
      --tlsRootCertFiles /hlf/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
      --isInit -c '${FCN_CALL}'

    echo \"Invoke Init CC: \$?\"
  "
}
##############################

source .env
source common.sh

pushd network/chaincode/asset-transfer-basic/go
docker image prune --filter label=stage=build -f
docker rmi "${CC_DOCKER_IMAGE}:${CC_DOCKER_TAG}" || true
docker rmi "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" || true
docker build \
  --build-arg GOPROXY="${GOPROXY}" \
  -t "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" .

if [ "${REG_USER}" ]; then
  docker login -u "${REG_USER}" -p "${REG_PASS}" "${REG_URL}"
fi
docker push "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}"
popd


cat > "${OUT_DIR}"/connection.json << EOF
{
  "address": "${CC_APP_HOST}:${CC_APP_PORT}",
  "dial_timeout": "10s",
  "tls_required": false
}
EOF
cat > "${OUT_DIR}"/metadata.json << EOF
{
  "type": "external",
  "label": "${CC_NAME}_${CC_VERSION}"
}
EOF

pushd "${OUT_DIR}"
tar cvfz code.tar.gz connection.json
tar cvfz "${CC_NAME}".tar.gz metadata.json code.tar.gz
popd

sudo mkdir -p "${NFS_DIR}"/chaincode
sudo cp -rf "${OUT_DIR}"/"${CC_NAME}".tar.gz "${NFS_DIR}"/chaincode

PEER0_ORG1_POD="$(kubectl -n ${NAMESPACE} get pod -l app.kubernetes.io/instance=peer0-org1 -o jsonpath="{.items[0].metadata.name}")"
PEER0_ORG2_POD="$(kubectl -n ${NAMESPACE} get pod -l app.kubernetes.io/instance=peer0-org2 -o jsonpath="{.items[0].metadata.name}")"

installCC "${PEER0_ORG1_POD}"
installCC "${PEER0_ORG2_POD}"

kubectl -n ${NAMESPACE} exec "${PEER0_ORG1_POD}" -c hlf-peer -- sh -c "
  export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}

  peer lifecycle chaincode queryinstalled
" >&log.txt
cat log.txt
PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
echo "PACKAGE_ID = ${PACKAGE_ID}"
if [ ! "${PACKAGE_ID}" ]; then
  echo "ERROR: no PACKAGE_ID"
  exit 1
fi

helm install basic helms/hlf-cc \
  --set image.repository="${CC_DOCKER_IMAGE}" \
  --set image.tag="${CC_DOCKER_TAG}" \
  --set image.pullPolicy="Always" \
  --set hlfCc.id="${PACKAGE_ID}" \
  --set hlfCc.address="0.0.0.0:${CC_APP_PORT}" \
  --set hlfCc.host="${CC_APP_HOST}"
waitForChart "basic"

approveForMyOrg "${PEER0_ORG1_POD}"
approveForMyOrg "${PEER0_ORG2_POD}"

commitCC "${PEER0_ORG1_POD}"

sleep 5

if [ "${CC_INIT_FCN}" ]; then
  invokeInitCC "${PEER0_ORG1_POD}"
  sleep 2
  echo "----------------"
  echo " Chaincode Logs"
  echo "----------------"
  kubectl -n ${NAMESPACE} logs -l app.kubernetes.io/instance=basic
fi