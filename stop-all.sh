#!/bin/bash

source .env
source common.sh

rm -rf "${OUT_DIR}" *.log
sudo rm -rf "${NFS_DIR}"/*

helm uninstall explorer || true
helm uninstall orderer || true
helm uninstall peer0-org1 || true
helm uninstall peer0-org2 || true
helm uninstall basic || true
waitForNoChart "explorer"
waitForNoChart "orderer"
waitForNoChart "peer0-org1"
waitForNoChart "peer0-org2"
waitForNoChart "basic"

helm uninstall ca-orderer || true
helm uninstall ca-org1 || true
helm uninstall ca-org2 || true
waitForNoChart "ca-orderer"
waitForNoChart "ca-org1"
waitForNoChart "ca-org2"

echo "*** FINISHED"