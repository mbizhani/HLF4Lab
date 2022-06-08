#!/bin/bash

source .env
source common.sh

if [ "${CC_LANG}" == "go" ]; then
  pushd network/chaincode/asset-transfer-basic/go
  docker rmi "${CC_DOCKER_IMAGE}:${CC_DOCKER_TAG}" || true
  docker rmi "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" || true
  docker build \
    --build-arg GOPROXY="${GOPROXY}" \
    -t "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" .

  if [ "${REG_USER}" ]; then
    docker login -u "${REG_USER}" -p "${REG_PASS}" "${REG_URL}"
  fi
  docker push "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}"
  popd
elif [ "${CC_LANG}" == "java" ]; then
  pushd network/chaincode/asset-transfer-basic/SpringBoot
  docker rmi "${CC_DOCKER_IMAGE}:${CC_DOCKER_TAG}" || true
  docker rmi "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" || true
  mvn clean package
  docker build -t "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}" .

  if [ "${REG_USER}" ]; then
    docker login -u "${REG_USER}" -p "${REG_PASS}" "${REG_URL}"
  fi
  docker push "${CC_DOCKER_PUSH_IMAGE}:${CC_DOCKER_TAG}"
  popd
else
  echo "ERROR: Invalid Chaincode Lang: ${CC_LANG}"
  exit 1
fi

helm upgrade basic helms/hlf-cc \
  --atomic \
  --reuse-values \
  --set-string podAnnotations.redeploy="$(date +'%Y-%m-%d_%H-%M-%S')"