#!/bin/bash

# need to change to the dedicated home directory
HOME=/home/prlab

check_root(){
    root=`whoami`
    if [[ "$root" == "root" ]]; then 
        return 0
    fi
    return 1
}

update_system(){
    eval "apt update && apt upgrade -y"
}


check_cgroup(){
# check the systeme is cgroup2 
cgroup=`ls  /sys/fs/cgroup/cgroup.controllers`
    if [ -n $cgroup ]; then
	    echo "cgroup2 found"
        return 0
    else
        echo "no cgroup2"
        return 1
    fi

}

#install_k8s(){

prerequisite(){

touch /etc/modules-load.d/k8s.conf
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack

cri_file=/etc/sysctl.d/99-kubernetes-cri.conf
touch $cri_file
cat > $cri_file << EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.conf.all.send_redirects = 0 
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
vm.swappiness = 0
EOF
}

install_cri(){
sysctl --system
echo 'deb http://deb.debian.org/debian buster-backports main' > /etc/apt/sources.list.d/backports.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 6ED0E7B82643E131
eval "DEBIAN_FRONTEND=noninteractive apt update -y"
eval "DEBIAN_FRONTEND=noninteractive apt install -y -t buster-backports libseccomp2 || apt update -y -t buster-backports libseccomp2"


export OS=xUbuntu_22.04
export VERSION=1.28


echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

mkdir -p /usr/share/keyrings

eval "curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg"

eval "curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg"

# install cri-o

eval "DEBIAN_FRONTEND=noninteractive apt-get update -y"
eval "DEBIAN_FRONTEND=noninteractive apt-get install cri-o cri-o-runc -y"
eval "systemctl daemon-reload"
eval "systemctl enable crio"
eval "systemctl start crio"

echo "Complete install CRI-O"
}

install_k8s(){
# install k8s 
export KUBE_VERSION=v1.28
eval "apt-get update -y"
# apt-transport-https may be a dummy package; if so, you can skip that package
eval "apt-get install -y apt-transport-https ca-certificates curl gpg"


eval "curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBE_VERSION/deb/Release.key | gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
rm /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBE_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
eval "DEBIAN_FRONTEND=noninteractive apt-get update -y"
eval "DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl"
eval "DEBIAN_FRONTEND=noninteractive apt-mark hold kubelet kubeadm kubectl"

echo "Complete install K8S"


mkdir -p /opt/deploy/k8s/
cat > /opt/deploy/k8s/kubeadm-config.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
controlPlaneEndpoint: "dk8scp1:6443"
bootstrapTokens:
- token: "abcdef.0123456789abcdef"
  description: "kubeadm bootstrap token"
  ttl: "24h"
- token: "ghijkl.9876543210ghijkl"
  description: "another bootstrap token"
  usages:
  - signing
  - authentication
  groups:
  - system:bootstrappers:kubeadm:default-node-token
nodeRegistration:
  criSocket: unix:///var/run/crio/crio.sock
  name: dk8scp1
localAPIEndpoint:
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
etcd:
  local:
    dataDir: /var/lib/etcd
networking:
  serviceSubnet: "10.96.0.0/16"
  podSubnet: "172.16.0.1/16"
  dnsDomain: "cluster.local"
scheduler: {}
kubernetesVersion: "v1.28.4"
controlPlaneEndpoint: "dk8scp1:6443"
apiServer:
  extraArgs:
    feature-gates: "KubeletCgroupDriverFromCRI=true"
  timeoutForControlPlane: 4m0s
certificatesDir: /etc/kubernetes/pki
controllerManager: {}
imageRepository: "registry.k8s.io"
clusterName: dk8scluster1

---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
podCIDR: 172.16.0.1/16
cpuManagerReconcilePeriod: 0s
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMinimumGCAge: 0s
logging: {}
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
resolvConf: /run/systemd/resolve/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 0s
shutdownGracePeriod: 0s
shutdownGracePeriodCriticalPods: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF

eval "systemctl enable --now kubelet"
eval "kubeadm init --v=5 --config=/opt/deploy/k8s/kubeadm-config.yaml \
    --skip-phases=addon/kube-proxy"
export HOME=/home/prlab


}
copy_k8s_config(){
  export HOME=/home/prlab
  export USER=prlab
  mkdir -p $HOME/.kube  
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown -R $USER:$USER $HOME/.kube/
  chown -R $USER:$USER $HOME/.kube/config


}
copy_host_file(){
    if [[ -z $1 ]]; then
        exit
    else
        cat $1 | tee -a /etc/hosts
    fi 
}

install_k8s_node(){
export KUBE_VERSION=v1.28
eval "DEBIAN_FRONTEND=noninteractive apt-get update -y" 
# apt-transport-https may be a dummy package; if so, you can skip that package
eval "DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl gpg"

curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBE_VERSION/deb/Release.key | gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
rm /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBE_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

eval "DEBIAN_FRONTEND=noninteractive apt-get update -y"
eval "DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl"
eval "DEBIAN_FRONTEND=noninteractive apt-mark hold kubelet kubeadm kubectl"
}


main(){


    if check_root; then         
        update_system
	    echo "Installing"
        copy_host_file $1
	    if ! command -v crio &>/dev/null; then
            prerequisite
	        install_cri
        fi
        if [[ $2 == "cp" ]]; then
            if ! command -v kubeadm &>/dev/null; then 
    	    install_k8s
	        echo "COPY K8S Config"
	        copy_k8s_config
    	    echo "Finish Setup K8S"
            fi
        else
            install_k8s_node
        fi
        exit

    else
        echo "Please execute the script with sudo"
        exit 1
    fi

}




main $@ 



