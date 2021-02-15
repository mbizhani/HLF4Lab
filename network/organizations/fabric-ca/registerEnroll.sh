#!/bin/bash

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

# println echos string
println() {
  echo -e "$1"
}

# errorln echos i red color
errorln() {
  println "${C_RED}${1}${C_RESET}"
}

# successln echos in green color
successln() {
  println "${C_GREEN}${1}${C_RESET}"
}

# infoln echos in blue color
infoln() {
  println "${C_BLUE}${1}${C_RESET}"
}

# warnln echos in yellow color
warnln() {
  println "${C_YELLOW}${1}${C_RESET}"
}

# fatalln echos in red color and exits with fail status
fatalln() {
  errorln "$1"
  exit 1
}

##############################
##############################

createMSP() {
#  CA_NAME="ca-org1"
#  CA_SERVER_URL="ca.org1.example.com:7054"
#  CA_SERVER_TLS_FILE="/hlf/fabric-ca/org1/tls-cert.pem"
#
#  ORG_FQDN="org1.example.com"
#  ORG_ADMIN="org1admin"
#  CMP_TYPE="peer"
#  CMP_NAME="peer0"


  CMP_FQDN="${CMP_NAME}.${ORG_FQDN}"
  FABRIC_CA_CLIENT_HOME="/hlf/organizations/${CMP_TYPE}Organizations/${ORG_FQDN}"
  CMP_HOME_DIR="${FABRIC_CA_CLIENT_HOME}/${CMP_TYPE}s/${CMP_FQDN}"

  export FABRIC_CA_CLIENT_HOME
  mkdir -p "${FABRIC_CA_CLIENT_HOME}"

  infoln "Enrolling the CA admin: ${CMP_FQDN}"
  set -x
  fabric-ca-client enroll \
    -u https://admin:adminpw@"${CA_SERVER_URL}" \
    --caname "${CA_NAME}" \
    --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/${CA_SERVER_URL//[.:]/-}-${CA_NAME}.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/${CA_SERVER_URL//[.:]/-}-${CA_NAME}.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/${CA_SERVER_URL//[.:]/-}-${CA_NAME}.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/${CA_SERVER_URL//[.:]/-}-${CA_NAME}.pem
    OrganizationalUnitIdentifier: orderer" >"${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml

  infoln "Registering ${CMP_FQDN}"
  set -x
  fabric-ca-client register --caname "${CA_NAME}" --id.name "${CMP_NAME}" --id.secret "${CMP_NAME}pw" --id.type "${CMP_TYPE}" --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  infoln "Registering Org Admin: ${CMP_FQDN}"
  set -x
  fabric-ca-client register --caname "${CA_NAME}" --id.name "${ORG_ADMIN}" --id.secret "${ORG_ADMIN}pw" --id.type admin --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  mkdir -p "${CMP_HOME_DIR}"

  infoln "Generating MSP: ${CMP_FQDN}"
  set -x
  fabric-ca-client enroll -u https://"${CMP_NAME}":"${CMP_NAME}pw"@"${CA_SERVER_URL}" --caname "${CA_NAME}" -M "${CMP_HOME_DIR}"/msp \
    --csr.hosts "${CMP_FQDN}" --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  cp "${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml "${CMP_HOME_DIR}"/msp/config.yaml

  infoln "Generating TLS Certificates: ${CMP_FQDN}"
  set -x
  fabric-ca-client enroll \
    -u https://"${CMP_NAME}":"${CMP_NAME}pw"@"${CA_SERVER_URL}" \
    --caname "${CA_NAME}" \
    -M "${CMP_HOME_DIR}"/tls \
    --enrollment.profile tls \
    --csr.hosts "${CMP_FQDN}" \
    --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  cp "${CMP_HOME_DIR}"/tls/tlscacerts/* "${CMP_HOME_DIR}"/tls/ca.crt
  cp "${CMP_HOME_DIR}"/tls/signcerts/* "${CMP_HOME_DIR}"/tls/server.crt
  cp "${CMP_HOME_DIR}"/tls/keystore/* "${CMP_HOME_DIR}"/tls/server.key

  if [ "${CMP_TYPE}" == "peer" ]; then
    mkdir -p "${FABRIC_CA_CLIENT_HOME}"/msp/tlscacerts
    cp "${CMP_HOME_DIR}"/tls/tlscacerts/* "${FABRIC_CA_CLIENT_HOME}"/msp/tlscacerts/ca.crt
    mkdir -p "${FABRIC_CA_CLIENT_HOME}"/tlsca
    cp "${CMP_HOME_DIR}"/tls/tlscacerts/* "${FABRIC_CA_CLIENT_HOME}"/tlsca/     #tlsca.org1.example.com-cert.pem
    mkdir -p "${FABRIC_CA_CLIENT_HOME}"/ca
    cp "${CMP_HOME_DIR}"/msp/cacerts/* "${FABRIC_CA_CLIENT_HOME}"/ca/           #ca.org1.example.com-cert.pem
  fi

  if [ "${CMP_TYPE}" == "orderer" ]; then
    mkdir -p "${CMP_HOME_DIR}"/msp/tlscacerts
    cp "${CMP_HOME_DIR}"/tls/tlscacerts/* "${CMP_HOME_DIR}"/msp/tlscacerts/           #tlsca.example.com-cert.pem
    mkdir -p "${FABRIC_CA_CLIENT_HOME}"/msp/tlscacerts
    cp "${CMP_HOME_DIR}"/tls/tlscacerts/* "${FABRIC_CA_CLIENT_HOME}"/msp/tlscacerts/  #tlsca.example.com-cert.pem
  fi

  infoln "Generating Org Admin MSP: ${CMP_FQDN}"
  mkdir -p "${FABRIC_CA_CLIENT_HOME}"/users/Admin@"${ORG_FQDN}"
  set -x
  fabric-ca-client enroll \
    -u https://"${ORG_ADMIN}":"${ORG_ADMIN}pw"@"${CA_SERVER_URL}" \
    --caname "${CA_NAME}" \
    -M "${FABRIC_CA_CLIENT_HOME}"/users/Admin@"${ORG_FQDN}"/msp \
    --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null
  cp "${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml "${FABRIC_CA_CLIENT_HOME}"/users/Admin@"${ORG_FQDN}"/msp/config.yaml
}

createPeer0Org1() {
  CA_NAME="ca-org1"
  CA_SERVER_URL="ca.org1.example.com:7054"
  CA_SERVER_TLS_FILE="/hlf/fabric-ca/org1/tls-cert.pem"

  ORG_FQDN="org1.example.com"
  ORG_ADMIN="org1admin"
  CMP_TYPE="peer"
  CMP_NAME="peer0"

  createMSP
}

createOrdererOrg1() {
  CA_NAME="ca-org1"
  CA_SERVER_URL="ca.org1.example.com:7054"
  CA_SERVER_TLS_FILE="/hlf/fabric-ca/org1/tls-cert.pem"

  ORG_FQDN="org1.example.com"
  ORG_ADMIN="org1admin"
  CMP_TYPE="orderer"
  CMP_NAME="orderer"

  createMSP
}

createPeer0Org2() {
  CA_NAME="ca-org2"
  CA_SERVER_URL="ca.org2.example.com:7054"
  CA_SERVER_TLS_FILE="/hlf/fabric-ca/org2/tls-cert.pem"

  ORG_FQDN="org2.example.com"
  ORG_ADMIN="org2admin"
  CMP_TYPE="peer"
  CMP_NAME="peer0"

  createMSP
}

createOrdererOrg2() {
  CA_NAME="ca-org2"
  CA_SERVER_URL="ca.org2.example.com:7054"
  CA_SERVER_TLS_FILE="/hlf/fabric-ca/org2/tls-cert.pem"

  ORG_FQDN="org2.example.com"
  ORG_ADMIN="org2admin"
  CMP_TYPE="orderer"
  CMP_NAME="orderer"

  createMSP
}

createOrderer() {
  CA_NAME="ca-orderer"
  CA_SERVER_URL="ca.example.com:7054"
  CA_SERVER_TLS_FILE="/hlf/fabric-ca/ordererOrg/tls-cert.pem"

  ORG_FQDN="example.com"
  ORG_ADMIN="ordererAdmin"
  CMP_TYPE="orderer"
  CMP_NAME="orderer"

  createMSP
}