#!/bin/bash

source .env
source common.sh

##############################

function commitCC() {
  local orgId=$1

  runInPeer "${orgId}" "
    peer lifecycle chaincode commit \
      -o ${ORDERER_URL} \
      --tls --cafile ${ORDERER_CA} \
      --channelID ${CHANNEL_NAME} \
      --name ${CC_NAME} \
      --version ${CC_VERSION} \
      --peerAddresses peer0.org1.example.com:$(peerPort 1) \
      --tlsRootCertFiles /hlf/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
      --peerAddresses peer0.org2.example.com:$(peerPort 2) \
      --tlsRootCertFiles /hlf/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
      --sequence ${CC_SEQUENCE}

    echo \"Commit CC: \$?\"
  "
}

#function checkCommitReadiness() {
#  PEER_POD="$1"
#  PARAM1="$2"
#
#  kubectl exec "${PEER_POD}" -c "${PEER_CTR}" -- sh -c "
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
#        --sequence ${CC_SEQUENCE} ${CC_INIT_REQUIRED} --output json >&chaincode.log
#
#      cat chaincode.log
#      sleep 2
#      CNT=\$(grep '${PARAM1}' chaincode.log -c)
#    done
#  "
#}

#function queryCommitted() {
#  PEER_POD="$1"
#  kubectl exec "${PEER_POD}" -c "${PEER_CTR}" -- sh -c "
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
  local orgId="$1"
  FCN_CALL='{"function":"'${CC_INIT_FCN}'","Args":[]}'

  runInPeer "${orgId}" "
    peer chaincode invoke \
      -o ${ORDERER_URL} \
      --tls --cafile ${ORDERER_CA} \
      --channelID ${CHANNEL_NAME} \
      --name ${CC_NAME} \
      --peerAddresses peer0.org1.example.com:$(peerPort 1) \
      --tlsRootCertFiles /hlf/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
      --peerAddresses peer0.org2.example.com:$(peerPort 2) \
      --tlsRootCertFiles /hlf/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
      -c '${FCN_CALL}'

    echo \"Invoke Init CC: \$?\"
  "
}

##############################

if [ "$1" != "-nb" ]; then
  pushd network/chaincode/asset-transfer-basic/SpringBoot
  docker rmi "${CC_DOCKER_IMAGE}:${CC_DOCKER_TAG}" || true
  docker rmi "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" || true
  mvn clean package
  docker build -t "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" .

  docker login -u "${REG_USER}" -p "${REG_PASS}" "${REG_PUSH_URL}"
  docker push "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}"
  popd
else
  echo "No Build for Chaincode, Use Current Image!"
fi

mkdir -p "${OUT_DIR}"/chaincode
# TIP: https://stackoverflow.com/questions/68670102/hyperledger-fabric-external-chaincode-with-tls-from-fabric-ca
if [ "${CC_TLS_ENABLED}" == "true" ]; then
  ROOTCA_CRT="$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "${OUT_DIR}"/organizations/ordererOrganizations/example.com/chaincode/tls/ca.crt)"
  CLIENT_KEY="$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "${OUT_DIR}"/organizations/ordererOrganizations/example.com/chaincode/msp/server.key)"
  CLIENT_CRT="$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "${OUT_DIR}"/organizations/ordererOrganizations/example.com/chaincode/msp/server.crt)"

  cat > "${OUT_DIR}"/chaincode/connection.json << EOF
{
  "address": "${CC_APP_HOST}:${CC_APP_PORT}",
  "dial_timeout": "10s",
  "tls_required": true,
  "client_auth_required": true,
  "client_key": "${CLIENT_KEY}",
  "client_cert": "${CLIENT_CRT}",
  "root_cert": "${ROOTCA_CRT}"
}
EOF
else
  cat > "${OUT_DIR}"/chaincode/connection.json << EOF
{
  "address": "${CC_APP_HOST}:${CC_APP_PORT}",
  "dial_timeout": "10s",
  "tls_required": false
}
EOF
fi
cat > "${OUT_DIR}"/chaincode/metadata.json << EOF
{
  "type": "external",
  "label": "${CC_NAME}_${CC_VERSION}"
}
EOF

pushd "${OUT_DIR}"/chaincode
tar cvfz code.tar.gz connection.json
tar cvfz "${CC_NAME}".tar.gz metadata.json code.tar.gz
popd

#sudo mkdir -p "${NFS_DIR}"/chaincode
#sudo cp -rf "${OUT_DIR}"/"${CC_NAME}".tar.gz "${NFS_DIR}"/chaincode
out2pv chaincode

installCC 1
installCC 2

helm install basic helms/hlf-cc \
  --set image.repository="${CC_DOCKER_IMAGE}" \
  --set image.tag="${CC_DOCKER_TAG}" \
  --set image.pullPolicy="Always" \
  --set hlfCc.id="$(getPackageId)" \
  --set hlfCc.address="0.0.0.0:${CC_APP_PORT}" \
  --set hlfCc.host="${CC_APP_HOST}" \
  --set hlfCc.nfs.path="${NFS_DIR}" \
  --set hlfCc.nfs.server="${NFS_SERVER}" \
  --set hlfCc.tls.enabled="${CC_TLS_ENABLED}"
waitForChart "basic"

approveCCForOrg 1
approveCCForOrg 2

commitCC 1
sleep 5

if [ "${CC_INIT_FCN}" ]; then
  invokeInitCC 2
  sleep 2
  echo "----------------"
  echo " Chaincode Logs"
  echo "----------------"
  kubectl -n "${NAMESPACE}" logs -l app.kubernetes.io/instance=basic
fi