#!/bin/bash

OUT_DIR="OUT"
mkdir -p ${OUT_DIR}

PEER_CTR="hlf-peer"
SERVICE_TYPE="NodePort"
CA_ORD_PORT=30100
CA_ORG1_PORT=30101
CA_ORG2_PORT=30102
ORDERER_PORT=30103
PEER_ORG1_PORT=30104
PEER_ORG2_PORT=30105

declare -A ORGS_CA_PORT=( ["1"]="${CA_ORG1_PORT}" ["2"]="${CA_ORG2_PORT}")
declare -A ORGS_PEER_PORT=( ["1"]="${PEER_ORG1_PORT}" ["2"]="${PEER_ORG2_PORT}")


ORDERER_URL="orderer.example.com:${ORDERER_PORT}"
ORDERER_CA=/hlf/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

export HELM_NAMESPACE=${NAMESPACE}

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