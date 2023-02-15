#!/bin/bash

source .env
source common.sh

orgId="3"

helm install ca-org${orgId} helms/hlf-ca \
  -f values/ca-org${orgId}.yaml \
  --set service.type="${SERVICE_TYPE}" \
  --set service.port="$(caPort ${orgId})" \
  --set hlfCa.nfs.path="${NFS_DIR}" \
  --set hlfCa.nfs.server="${NFS_SERVER}"

waitForChart "ca-org${orgId}"

CA_POD="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance=ca-org${orgId} -o jsonpath="{.items[0].metadata.name}")"

kubectl -n "${NAMESPACE}" exec "${CA_POD}" -- sh -c "
  . /hlf/fabric-ca/registerEnroll.sh
  createOrg ${orgId} $(caPort ${orgId})
"
