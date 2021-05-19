#!/bin/bash

OUT_DIR="OUT"
mkdir -p ${OUT_DIR}

PEER_PORT=7051
CA_PORT=7054

ORDERER_URL=orderer.example.com:7050
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