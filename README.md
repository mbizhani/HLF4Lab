# HLF4Lab
A lab environment to deploy **Hyperledger Fabric** to **Kubernetes** with **External Chaincode**

## Prerequisites
- A Linux machine
- A Kubernetes cluster (e.g. `minikube` or other distribution using vm(s) on your machine)
  - You can easily setup a cluster via `rke` following [[Kubernetes Recipe - RKE](https://www.devocative.org/article/tech/k8s-rke)]
- Your current user must be in `sudo` group
  - `root# usermod -aG sudo USERNAME`
- Install NFS service on your machine
  - `sudo apt install nfs-kernel-server`
  - `sudo mkdir -p /opt/NFS/HLF && chmod 777 /opt/NFS/HLF`
  - Update `/etc/exports` and add following record:
    ```text
    /opt/NFS/HLF   YOUR_MACHINE_IP(rw,sync,no_root_squash,no_subtree_check,insecure)
    ``` 
  - `sudo systemctl restart nfs-server.service`
- Install `helm` [[REF](https://helm.sh/docs/intro/install/)]
  - Download the latest stable version
  - Unarchive it
  - Add `helm` binary in your `PATH`
  - [Optional] Add bash completion in your `~/.bashrc`
    - `echo "source <(helm completion bash)" >> ~/.bashrc`
- [Optional] Install a docker registry for pushing your external chaincode image [[REF](https://docs.docker.com/registry/)]

## Setup Network
- Update `.env` due to your settings
  - Based on `NAMESPACE` variable, `hlf4lab` is the target namespace
- Update helm chart values files in `values` directory if necessary
- Update CoreDNS config map and add following `rewrite` records
  - `kubectl edit cm -n kube-system coredns`
    - or `kubectl edit cm -n kube-system $(kubectl -n kube-system get cm -l k8s-app=kube-dns -o jsonpath="{.items[0].metadata.name}")`
  - Records
    ```text
    rewrite name ca.example.com      ca-orderer-hlf-ca.hlf4lab.svc.cluster.local
    rewrite name ca.org1.example.com ca-org1-hlf-ca.hlf4lab.svc.cluster.local
    rewrite name ca.org2.example.com ca-org2-hlf-ca.hlf4lab.svc.cluster.local

    rewrite name orderer.example.com       orderer-hlf-orderer.hlf4lab.svc.cluster.local
    rewrite name peer0.org1.example.com    peer0-org1-hlf-peer.hlf4lab.svc.cluster.local
    rewrite name peer0.org2.example.com    peer0-org2-hlf-peer.hlf4lab.svc.cluster.local
    rewrite name basic-cc.org1.example.com basic-hlf-cc.hlf4lab.svc.cluster.local
    ```
   - Note: the `.hlf4lab.` in the records is the target namespace 
   - Restart its pod
     - `kubectl delete po -n kube-system $(kubectl get po -n kube-system -l k8s-app=kube-dns -o jsonpath="{.items[0].metadata.name}")`
     - Wait until its `Running` state 
- `git clone https://github.com/mbizhani/HLF4Lab.git`
- cd `HLF4Lab`
- Download fabric binaries [[hyperledger-fabric-linux-amd64-2.2.0.tar.gz](https://github.com/hyperledger/fabric/releases/download/v2.2.0/hyperledger-fabric-linux-amd64-2.2.0.tar.gz)]
  - Unarchive it
  - Copy the `bin` directory to `HLF4Lab` directory
  - Note: only `configtxgen` is required
- `./start-ca-servers.sh`
  - `wget -qO - --no-check-certificate https://ca.example.com/cainfo`
  - `wget -qO - --no-check-certificate https://ca.org1.example.com/cainfo`
  - `wget -qO - --no-check-certificate https://ca.org2.example.com/cainfo`
- `./start-network.sh`
- `./start-ext-cc.sh`
  - This step compiles the Go chain code, and it uses `https://proxy.golang.org` as Go proxy, defined in `.env`. 
    If you have trouble accessing this site, you can set other proxy such as `https://goproxy.io`.

Now, if everything executed successfully, you should see the logs of the chain code like following text:
```text
2021/05/23 06:00:47 Config: CHAINCODE_ID=[basic_1.0:2aeb3613f13edba4fb0805dcbd4e31982b8a4b2f7487f9bb214d3eca4ccc4819] CHAINCODE_SERVER_ADDRESS=[0.0.0.0:9999]
2021/05/23 06:00:47 Server Created Successfully!
2021/05/23 06:01:01 InitLedger()
2021/05/23 06:01:01 InitLedger: Asset Added [asset1]
2021/05/23 06:01:01 InitLedger: Asset Added [asset2]
2021/05/23 06:01:01 InitLedger: Asset Added [asset3]
2021/05/23 06:01:01 InitLedger: Asset Added [asset4]
2021/05/23 06:01:01 InitLedger: Asset Added [asset5]
2021/05/23 06:01:01 InitLedger: Asset Added [asset6]
```

## Uninstall the Network
Execute `stop-all.sh` to uninstall all charts and remove all the generated files from your local and NFS.