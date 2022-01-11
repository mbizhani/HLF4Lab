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

waitForFile() {
  FILE=$1

  while [ ! -f ${FILE} ]; do
    warnln "Waiting for file: ${FILE}"
    sleep 2
  done

  infoln "File Existed: ${FILE}"
}

##############################
##############################

createOrg1() {
  ca_port="${1:-7054}"
  infoln "Enrolling the CA admin: port=${ca_port}"

  CA_NAME="ca-org1"
  CA_SERVER_URL="ca.org1.example.com:${ca_port}"
  CA_SERVER_TLS_FILE="/hlf/fabric-ca/org1/tls-cert.pem"
  export FABRIC_CA_CLIENT_HOME="/hlf/organizations/peerOrganizations/org1.example.com"
  mkdir -p ${FABRIC_CA_CLIENT_HOME}

  waitForFile "${CA_SERVER_TLS_FILE}"

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@${CA_SERVER_URL} --caname ${CA_NAME} --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca-org1-example-com-${ca_port}-ca-org1.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca-org1-example-com-${ca_port}-ca-org1.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca-org1-example-com-${ca_port}-ca-org1.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca-org1-example-com-${ca_port}-ca-org1.pem
    OrganizationalUnitIdentifier: orderer" >${FABRIC_CA_CLIENT_HOME}/msp/config.yaml

  infoln "Registering peer0"
  set -x
  fabric-ca-client register --caname ${CA_NAME} --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  infoln "Registering user"
  set -x
  fabric-ca-client register --caname ${CA_NAME} --id.name user1 --id.secret user1pw --id.type client --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  infoln "Registering the org admin"
  set -x
  fabric-ca-client register --caname ${CA_NAME} --id.name org1admin --id.secret org1adminpw --id.type admin --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  CMP_HOME_DIR="${FABRIC_CA_CLIENT_HOME}"/peers/peer0.org1.example.com
  mkdir -p "${CMP_HOME_DIR}"

  infoln "Generating the peer0 msp"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@${CA_SERVER_URL} --caname ${CA_NAME} -M ${CMP_HOME_DIR}/msp \
    --csr.hosts peer0.org1.example.com --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  cp "${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml "${CMP_HOME_DIR}"/msp/config.yaml

  infoln "Generating the peer0-tls certificates"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@${CA_SERVER_URL} --caname ${CA_NAME} -M ${CMP_HOME_DIR}/tls --enrollment.profile tls --csr.hosts peer0.org1.example.com --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  cp ${CMP_HOME_DIR}/tls/tlscacerts/* ${CMP_HOME_DIR}/tls/ca.crt
  cp ${CMP_HOME_DIR}/tls/signcerts/* ${CMP_HOME_DIR}/tls/server.crt
  cp ${CMP_HOME_DIR}/tls/keystore/* ${CMP_HOME_DIR}/tls/server.key

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts
  cp ${CMP_HOME_DIR}/tls/tlscacerts/* ${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts/ca.crt

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/tlsca
  cp ${CMP_HOME_DIR}/tls/tlscacerts/* ${FABRIC_CA_CLIENT_HOME}/tlsca/tlsca.org1.example.com-cert.pem

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/ca
  cp ${CMP_HOME_DIR}/msp/cacerts/* ${FABRIC_CA_CLIENT_HOME}/ca/ca.org1.example.com-cert.pem

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/users/User1@org1.example.com

  infoln "Generating the user msp"
  set -x
  fabric-ca-client enroll -u https://user1:user1pw@${CA_SERVER_URL} --caname ${CA_NAME} -M ${FABRIC_CA_CLIENT_HOME}/users/User1@org1.example.com/msp --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  cp ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml ${FABRIC_CA_CLIENT_HOME}/users/User1@org1.example.com/msp/config.yaml

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/users/Admin@org1.example.com

  infoln "Generating the org admin msp"
  set -x
  fabric-ca-client enroll -u https://org1admin:org1adminpw@${CA_SERVER_URL} --caname ${CA_NAME} -M ${FABRIC_CA_CLIENT_HOME}/users/Admin@org1.example.com/msp --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  cp ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml ${FABRIC_CA_CLIENT_HOME}/users/Admin@org1.example.com/msp/config.yaml
}

createOrg2() {
  ca_port="${1:-7054}"
  infoln "Enrolling the CA admin: port=${ca_port}"

  CA_NAME="ca-org2"
  CA_SERVER_URL="ca.org2.example.com:${ca_port}"
  CA_SERVER_TLS_FILE="/hlf/fabric-ca/org2/tls-cert.pem"
  export FABRIC_CA_CLIENT_HOME="/hlf/organizations/peerOrganizations/org2.example.com"
  mkdir -p ${FABRIC_CA_CLIENT_HOME}

  waitForFile "${CA_SERVER_TLS_FILE}"

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@${CA_SERVER_URL} --caname ${CA_NAME} --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca-org2-example-com-${ca_port}-ca-org2.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca-org2-example-com-${ca_port}-ca-org2.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca-org2-example-com-${ca_port}-ca-org2.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca-org2-example-com-${ca_port}-ca-org2.pem
    OrganizationalUnitIdentifier: orderer" >${FABRIC_CA_CLIENT_HOME}/msp/config.yaml

  infoln "Registering peer0"
  set -x
  fabric-ca-client register --caname ${CA_NAME} --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  infoln "Registering user"
  set -x
  fabric-ca-client register --caname ${CA_NAME} --id.name user1 --id.secret user1pw --id.type client --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  infoln "Registering the org admin"
  set -x
  fabric-ca-client register --caname ${CA_NAME} --id.name org2admin --id.secret org2adminpw --id.type admin --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  CMP_HOME_DIR="${FABRIC_CA_CLIENT_HOME}"/peers/peer0.org2.example.com
  mkdir -p "${CMP_HOME_DIR}"

  infoln "Generating the peer0 msp"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@${CA_SERVER_URL} --caname ${CA_NAME} -M ${CMP_HOME_DIR}/msp --csr.hosts peer0.org2.example.com --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  cp "${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml "${CMP_HOME_DIR}"/msp/config.yaml

  infoln "Generating the peer0-tls certificates"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@${CA_SERVER_URL} --caname ${CA_NAME} -M ${CMP_HOME_DIR}/tls --enrollment.profile tls --csr.hosts peer0.org2.example.com --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  cp ${CMP_HOME_DIR}/tls/tlscacerts/* ${CMP_HOME_DIR}/tls/ca.crt
  cp ${CMP_HOME_DIR}/tls/signcerts/* ${CMP_HOME_DIR}/tls/server.crt
  cp ${CMP_HOME_DIR}/tls/keystore/* ${CMP_HOME_DIR}/tls/server.key

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts
  cp ${CMP_HOME_DIR}/tls/tlscacerts/* ${FABRIC_CA_CLIENT_HOME}/msp/tlscacerts/ca.crt

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/tlsca
  cp ${CMP_HOME_DIR}/tls/tlscacerts/* ${FABRIC_CA_CLIENT_HOME}/tlsca/tlsca.org2.example.com-cert.pem

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/ca
  cp ${CMP_HOME_DIR}/msp/cacerts/* ${FABRIC_CA_CLIENT_HOME}/ca/ca.org2.example.com-cert.pem

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/users/User1@org2.example.com

  infoln "Generating the user msp"
  set -x
  fabric-ca-client enroll -u https://user1:user1pw@${CA_SERVER_URL} --caname ${CA_NAME} -M ${FABRIC_CA_CLIENT_HOME}/users/User1@org2.example.com/msp --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  cp ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml ${FABRIC_CA_CLIENT_HOME}/users/User1@org2.example.com/msp/config.yaml

  mkdir -p ${FABRIC_CA_CLIENT_HOME}/users/Admin@org2.example.com

  infoln "Generating the org admin msp"
  set -x
  fabric-ca-client enroll -u https://org2admin:org2adminpw@${CA_SERVER_URL} --caname ${CA_NAME} -M ${FABRIC_CA_CLIENT_HOME}/users/Admin@org2.example.com/msp --tls.certfiles ${CA_SERVER_TLS_FILE}
  { set +x; } 2>/dev/null

  cp ${FABRIC_CA_CLIENT_HOME}/msp/config.yaml ${FABRIC_CA_CLIENT_HOME}/users/Admin@org2.example.com/msp/config.yaml
}

createOrderer() {
  ca_port="${1:-7054}"
  infoln "Enrolling the CA admin: port=${ca_port}"

  CA_NAME="ca-orderer"
  CA_SERVER_URL="ca.example.com:${ca_port}"
  CA_SERVER_TLS_FILE="/hlf/fabric-ca/ordererOrg/tls-cert.pem"
  export FABRIC_CA_CLIENT_HOME="/hlf/organizations/ordererOrganizations/example.com"
  mkdir -p ${FABRIC_CA_CLIENT_HOME}

  waitForFile "${CA_SERVER_TLS_FILE}"

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@${CA_SERVER_URL} --caname ${CA_NAME} --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca-example-com-${ca_port}-ca-orderer.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca-example-com-${ca_port}-ca-orderer.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca-example-com-${ca_port}-ca-orderer.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca-example-com-${ca_port}-ca-orderer.pem
    OrganizationalUnitIdentifier: orderer" >"${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml

  infoln "Registering orderer"
  set -x
  fabric-ca-client register --caname ${CA_NAME} --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  infoln "Registering the orderer admin"
  set -x
  fabric-ca-client register --caname ${CA_NAME} --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  CMP_HOME_DIR="${FABRIC_CA_CLIENT_HOME}"/orderers/orderer.example.com
  mkdir -p "${CMP_HOME_DIR}"

  infoln "Generating the orderer msp"
  set -x
  fabric-ca-client enroll -u https://orderer:ordererpw@${CA_SERVER_URL} --caname ${CA_NAME} -M "${CMP_HOME_DIR}"/msp --csr.hosts orderer.example.com --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  cp "${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml "${CMP_HOME_DIR}"/msp/config.yaml

  infoln "Generating the orderer-tls certificates"
  set -x
  fabric-ca-client enroll -u https://orderer:ordererpw@${CA_SERVER_URL} --caname ${CA_NAME} -M "${CMP_HOME_DIR}"/tls --enrollment.profile tls --csr.hosts orderer.example.com --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  cp "${CMP_HOME_DIR}"/tls/tlscacerts/* "${CMP_HOME_DIR}"/tls/ca.crt
  cp "${CMP_HOME_DIR}"/tls/signcerts/* "${CMP_HOME_DIR}"/tls/server.crt
  cp "${CMP_HOME_DIR}"/tls/keystore/* "${CMP_HOME_DIR}"/tls/server.key

  mkdir -p "${CMP_HOME_DIR}"/msp/tlscacerts
  cp "${CMP_HOME_DIR}"/tls/tlscacerts/* "${CMP_HOME_DIR}"/msp/tlscacerts/tlsca.example.com-cert.pem

  mkdir -p "${FABRIC_CA_CLIENT_HOME}"/msp/tlscacerts
  cp "${CMP_HOME_DIR}"/tls/tlscacerts/* "${FABRIC_CA_CLIENT_HOME}"/msp/tlscacerts/tlsca.example.com-cert.pem

  mkdir -p "${FABRIC_CA_CLIENT_HOME}"/users
  mkdir -p "${FABRIC_CA_CLIENT_HOME}"/users/Admin@example.com

  infoln "Generating the admin msp"
  set -x
  fabric-ca-client enroll -u https://ordererAdmin:ordererAdminpw@${CA_SERVER_URL} --caname ${CA_NAME} -M "${FABRIC_CA_CLIENT_HOME}"/users/Admin@example.com/msp --tls.certfiles "${CA_SERVER_TLS_FILE}"
  { set +x; } 2>/dev/null

  cp "${FABRIC_CA_CLIENT_HOME}"/msp/config.yaml "${FABRIC_CA_CLIENT_HOME}"/users/Admin@example.com/msp/config.yaml
}
