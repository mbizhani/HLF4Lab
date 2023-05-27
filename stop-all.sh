#!/bin/bash

source .env
source common.sh

###
ALL_CHARTS="$(helm list -q)"

for CHART in ${ALL_CHARTS}; do
  helm uninstall "${CHART}"
done

for CHART in ${ALL_CHARTS}; do
  waitForNoChart "${CHART}"
done

kubectl delete pod -n "${NAMESPACE}" --force=true busybox
###
rm -rf "${OUT_DIR}"

echo "*** FINISHED"