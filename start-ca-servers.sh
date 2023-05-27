#!/bin/bash

source .env
source common.sh

eval "cat <<EOF
$(<network/k8s/busybox.yml)
EOF" > "${OUT_DIR}"/busybox.yml
kubectl apply -f "${OUT_DIR}"/busybox.yml
waitForChart busybox


cp -rf network/organizations/fabric-ca "${OUT_DIR}"
for ORG_ID in 1 2; do
  mkdir -p "${OUT_DIR}"/fabric-ca/org${ORG_ID}
  eval "cat <<EOF
$(<network/organizations/fabric-ca-server-config-ORG.yaml)
EOF" > "${OUT_DIR}"/fabric-ca/org${ORG_ID}/fabric-ca-server-config.yaml
done

out2nfs fabric-ca

##############
# ORDERER  CA
##############
helm install ca-orderer helms/hlf-ca \
  --create-namespace \
  --set service.type="${SERVICE_TYPE}" \
  --set service.port="${CA_ORD_PORT}" \
  --set hlfCa.nfs.path="${NFS_DIR}" \
  --set hlfCa.nfs.server="${NFS_SERVER}" \
  -f - <<EOF
hlfCa:
  config:
    serverConfigDir: fabric-ca/ordererOrg
image:
  repository: ${REG_URL}/hyperledger/fabric-ca
ingress:
  enabled: true
  hosts:
    - host: ca.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
EOF

waitForChart "ca-orderer"

CA_ORDERER_POD="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/instance=ca-orderer -o jsonpath="{.items[0].metadata.name}")"
kubectl -n "${NAMESPACE}" exec "${CA_ORDERER_POD}" -- sh -c "
  . /hlf/fabric-ca/registerEnroll.sh
  createOrderer ${CA_ORD_PORT}
"

################
# ORG 1 & 2  CA
################
for ORG_ID in 1 2; do
  installCA4Org ${ORG_ID}
done
