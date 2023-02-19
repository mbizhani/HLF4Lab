#!/bin/bash

source .env
source common.sh

rm -rf "${OUT_DIR}" *.log
sudo rm -rf "${NFS_DIR}"/*

ALL_CHARTS="$(helm list -q)"

for CHART in ${ALL_CHARTS}; do
  helm uninstall "${CHART}"
done

for CHART in ${ALL_CHARTS}; do
  waitForNoChart "${CHART}"
done

echo "*** FINISHED"