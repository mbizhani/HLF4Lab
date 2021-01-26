FROM golang:1.14.13-alpine3.12 AS build
LABEL stage=build
WORKDIR /go/src/github.com/hyperledger/fabric-samples/asset-transfer-basic/chaincode-external
COPY . .
ARG GOPROXY=https://proxy.golang.org
ARG GO111MODULE=on
RUN echo "Build.GOPROXY=${GOPROXY}" && \
    go build -o chaincode -v .


FROM alpine:3.12 AS prod
COPY --from=build /go/src/github.com/hyperledger/fabric-samples/asset-transfer-basic/chaincode-external/chaincode /app/chaincode
EXPOSE 9999
CMD /app/chaincode
