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
    orgId="${1}"
    echo "$(( CA_BASE_PORT + orgId ))"
}

function peerPort() {
    orgId="${1}"
    echo "$(( PEER_BASE_PORT + orgId ))"
}

##

function waitForChart() {
  CHART=$1
  while [ "$(kubectl -n ${NAMESPACE} get pod -l app.kubernetes.io/instance="${CHART}" | wc -l )" == "0" ] ||
        [ "$(kubectl -n ${NAMESPACE} get pod -l app.kubernetes.io/instance="${CHART}" -o jsonpath="{.items[0].status.phase}")" != "Running" ]; do
    echo "Waiting for ${CHART} ..."
    sleep 2
  done
}

function waitForNoChart() {
  CHART=$1
  while [ "$(kubectl -n ${NAMESPACE} get pod -l app.kubernetes.io/instance="${CHART}" | wc -l )" == "2" ]; do
    echo "Waiting for no ${CHART} ..."
    sleep 3
  done
}

##

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function yaml_ccp {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        network/organizations/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

##

function installCA4Org() {
  ORG_ID="${1}"

  helm install ca-org"${ORG_ID}" helms/hlf-ca \
    --set service.type="${SERVICE_TYPE}" \
    --set service.port="$(caPort "${ORG_ID}")" \
    --set hlfCa.nfs.path="${NFS_DIR}" \
    --set hlfCa.nfs.server="${NFS_SERVER}" \
    -f - <<EOF
hlfCa:
  config:
    serverConfigDir: fabric-ca/org${ORG_ID}
image:
  repository: ${REG_URL}/hyperledger/fabric-ca
ingress:
  enabled: true
  hosts:
    - host: ca.org${ORG_ID}.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
EOF

  waitForChart "ca-org${ORG_ID}"

  sleep 2

  CA_ORG_POD="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance=ca-org"${ORG_ID}" -o jsonpath="{.items[0].metadata.name}")"
  kubectl -n "${NAMESPACE}" exec "${CA_ORG_POD}" -- sh -c "
    . /hlf/fabric-ca/registerEnroll.sh
    createOrg ${ORG_ID} $(caPort "${ORG_ID}")
  "
}