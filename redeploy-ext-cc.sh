#!/bin/bash

source .env
source common.sh

pushd network/chaincode/asset-transfer-basic/SpringBoot
docker rmi "${CC_DOCKER_IMAGE}:${CC_DOCKER_TAG}" || true
docker rmi "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" || true
mvn clean package
docker build -t "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" .

docker login -u "${REG_USER}" -p "${REG_PASS}" "${REG_PUSH_URL}"
docker push "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}"
popd

helm upgrade basic helms/hlf-cc \
  --atomic \
  --reuse-values \
  --set-string podAnnotations.redeploy="$(date +'%Y-%m-%d_%H-%M-%S')"