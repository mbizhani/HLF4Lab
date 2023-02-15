#!/bin/bash

source .env
source common.sh

sudo bash -c \
  "cp -f ${NFS_DIR}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/* \
         ${NFS_DIR}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/priv_sk"

export PGPASSWORD="${EXPLORER_PGS_PASS}"
psql -h "${EXPLORER_PGS_HOST}" -U "${EXPLORER_PGS_USER}" -d "${EXPLORER_PGS_DB}" -f network/explorer/explorerpg.sql \
  -v dbname='db_hl_explorer' -v user='u_hl_explorer' -v passwd="'u_hl_explorer'"

helm install explorer helms/hl-explorer \
  -f values/explorer.yaml \
  --set hlExplorer.nfs.path="${NFS_DIR}" \
  --set hlExplorer.nfs.server="${NFS_SERVER}" \
  --set hlExplorer.db.host="${EXPLORER_PGS_HOST}" \
  --set hlExplorer.peer_org1.port="$(peerPort 1)"

