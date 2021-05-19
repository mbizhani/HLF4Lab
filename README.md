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
  - Download the latest stable version: [Installing Helm](https://helm.sh/docs/intro/install/)
  - Unarchive it
  - Add `helm` binary in your `PATH`
  - [Optional] Add bash completion in your `~/.bashrc`
    - `echo "source <(helm completion bash)" >> ~/.bashrc`
- [Optional] Install a docker registry for pushing your external chaincode image

## Set up components & channel
- Update `.env` due to your settings
  - Due to `NAMESPACE` variable, `hlf4lab` is the target namespace
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
- `./start-network.sh`
- `./start-ext-cc.sh`
