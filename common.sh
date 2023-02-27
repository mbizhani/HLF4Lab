#!/bin/bash

OUT_DIR="OUT"
mkdir -p ${OUT_DIR}

PEER_CTR="hlf-peer"
SERVICE_TYPE="NodePort"

CA_ORD_PORT=30100
CA_BASE_PORT=30100

ORDERER_PORT=30150
PEER_BASE_PORT=30150


ORDERER_URL="orderer.example.com:${ORDERER_PORT}"
ORDERER_CA=/hlf/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

export HELM_NAMESPACE=${NAMESPACE}

##

function caPort() {
    local orgId="${1}"
    echo "$(( CA_BASE_PORT + orgId ))"
}

function peerPort() {
    local orgId="${1}"
    echo "$(( PEER_BASE_PORT + orgId ))"
}

##

function waitForChart() {
  local chart=$1
  while [ "$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance="${chart}" | wc -l )" == "0" ] ||
        [ "$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance="${chart}" -o jsonpath="{.items[0].status.phase}")" != "Running" ]; do
    echo "Waiting for ${chart} ..."
    sleep 2
  done
}

function waitForNoChart() {
  local chart=$1
  while [ "$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance="${chart}" | wc -l )" == "2" ]; do
    echo "Waiting for no ${chart} ..."
    sleep 3
  done
}

function waitForFile() {
  local FILE=$1

  while [ ! -f "${FILE}" ]; do
    echo "Waiting for file ${FILE} ..."
    sleep 2
  done
}

##

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function yaml_ccp {
    local PP=$(one_line_pem "$4")
    local CP=$(one_line_pem "$5")
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        network/organizations/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

##

function installCA4Org() {
  local orgId="${1}"

  helm install ca-org"${orgId}" helms/hlf-ca \
    --set service.type="${SERVICE_TYPE}" \
    --set service.port="$(caPort "${orgId}")" \
    --set hlfCa.nfs.path="${NFS_DIR}" \
    --set hlfCa.nfs.server="${NFS_SERVER}" \
    -f - <<EOF
hlfCa:
  config:
    serverConfigDir: fabric-ca/org${orgId}
image:
  repository: ${REG_URL}/hyperledger/fabric-ca
ingress:
  enabled: true
  hosts:
    - host: ca.org${orgId}.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
EOF

  waitForChart "ca-org${orgId}"

  sleep 2

  local CA_ORG_POD="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance=ca-org"${orgId}" -o jsonpath="{.items[0].metadata.name}")"
  kubectl -n "${NAMESPACE}" exec "${CA_ORG_POD}" -- sh -c "
    . /hlf/fabric-ca/registerEnroll.sh
    createOrg ${orgId} $(caPort "${orgId}")
  "

  # Create Connection Profile
  local PEER_PEM="${NFS_DIR}/organizations/peerOrganizations/org${orgId}.example.com/tlsca/tlsca.org${orgId}.example.com-cert.pem"
  local CA_PEM="${NFS_DIR}/organizations/peerOrganizations/org${orgId}.example.com/ca/ca.org${orgId}.example.com-cert.pem"

  waitForFile "${PEER_PEM}"
  waitForFile "${CA_PEM}"

  mkdir -p "${OUT_DIR}/organizations/peerOrganizations/org${orgId}.example.com"

  echo "$(yaml_ccp ${orgId} "$(peerPort ${orgId})" "$(caPort ${orgId})" "${PEER_PEM}" "${CA_PEM}")" > \
    "${OUT_DIR}/organizations/peerOrganizations/org${orgId}.example.com/connection-org${orgId}.yaml"
}

function installPeerByChart() {
  local orgId=$1

  helm install "peer0-org${orgId}" helms/hlf-peer \
    --set service.type="${SERVICE_TYPE}" \
    --set service.port="$(peerPort "${orgId}")" \
    --set hlfPeer.nfs.path="${NFS_DIR}" \
    --set hlfPeer.nfs.server="${NFS_SERVER}" \
    -f - <<EOF
hlfPeer:
  config:
    mspId: Org${orgId}MSP
    fqdn: peer0.org${orgId}.example.com
    cmpDir: organizations/peerOrganizations/org${orgId}.example.com/peers/peer0.org${orgId}.example.com
    adminMspDir: organizations/peerOrganizations/org${orgId}.example.com/users/Admin@org${orgId}.example.com/msp
  couchdb:
    image: ${REG_URL}/couchdb:3.1.1

image:
  repository: ${REG_URL}/hyperledger/fabric-peer
EOF

  waitForChart "peer0-org${orgId}"
}

function runInPeer() {
  local orgId=$1
  local SCRIPT=$2
  local PEER0_ORG_POD="$(kubectl -n "${NAMESPACE}" get pod -l "app.kubernetes.io/instance=peer0-org${orgId}" -o jsonpath="{.items[0].metadata.name}")"

  kubectl -n "${NAMESPACE}" exec "${PEER0_ORG_POD}" -c "${PEER_CTR}"  -- sh -c "
  export CORE_PEER_MSPCONFIGPATH=\${ADMIN_MSP_DIR}

  ${SCRIPT}
  "
}

function fetchChannelConfigBlock() {
  local destDir=$1
  local configBlockPb=$2
  local configBlockJson=$3
  local configJson=$4

  runInPeer 1 "
    peer channel fetch config /hlf/config_block.pb \
      -o ${ORDERER_URL} \
      --tls --cafile ${ORDERER_CA} \
      -c ${CHANNEL_NAME}
    "

  waitForFile "${NFS_DIR}"/config_block.pb
  sudo mv "${NFS_DIR}"/config_block.pb "${destDir}/${configBlockPb}"
  sudo chown "$(id -u)":"$(id -g)" "${destDir}/${configBlockPb}"

  bin/configtxlator proto_decode \
    --type common.Block \
    --input  "${destDir}/${configBlockPb}" \
    --output "${destDir}/${configBlockJson}"

  jq \
    .data.data[0].payload.data.config \
    "${destDir}/${configBlockJson}" > "${destDir}/${configJson}"
}

function createUpdateConfigBlock() {
  local destDir=$1
  local config_json=$2
  local modified_config_json=$3
  local idx=$4

  local modified_config_pb="$((idx + 0))-modified_config.pb"
  local original_config_pb="$((idx + 1))-original_config.pb"
  local config_update_pb="$((idx + 1))-config_update.pb"
  local config_update_json="$((idx + 2))-config_update.json"
  local config_update_in_envelope_json="$((idx + 3))-config_update_in_envelope.json"
  local config_update_in_envelope_pb="$((idx + 4))-config_update_in_envelope.pb"

  echo "--- Gen: $((idx + 0))"
  bin/configtxlator proto_encode \
    --type common.Config \
    --input "${destDir}/${modified_config_json}" \
    --output "${destDir}/${modified_config_pb}"

  echo "--- Gen: $((idx + 1))"
  bin/configtxlator proto_encode \
    --type common.Config \
    --input "${destDir}/${config_json}" \
    --output "${destDir}/${original_config_pb}"

  bin/configtxlator compute_update \
    --channel_id "${CHANNEL_NAME}" \
    --original "${destDir}/${original_config_pb}" \
    --updated "${destDir}/${modified_config_pb}" \
    --output "${destDir}/${config_update_pb}"

  echo "--- Gen: $((idx + 2))"
  bin/configtxlator proto_decode \
    --type common.ConfigUpdate \
    --input "${destDir}/${config_update_pb}" \
    --output "${destDir}/${config_update_json}"

  echo "--- Gen: $((idx + 3))"
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_NAME}'", "type":2}},"data":{"config_update":'$(cat "${destDir}/${config_update_json}")'}}}' | jq . > "${ADD_ORG_DIR}/${config_update_in_envelope_json}"

  echo "--- Gen: $((idx + 4))"
  bin/configtxlator proto_encode \
    --type common.Envelope \
   --input "${destDir}/${config_update_in_envelope_json}" \
   --output "${destDir}/${config_update_in_envelope_pb}"

}