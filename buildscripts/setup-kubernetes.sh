#!/bin/sh -eu

if [ "$(id -ur)" -ne "0" ]; then
    echo "$0 can only be run as root. Use sudo."
    exit 1
fi

if [ "" = "${KUBE_VERSION:-}" ]; then
    echo "KUBE_VERSION must be specified."
    exit 1
fi

## Change default sandbox image version
## Sandbox Image version is the default version of the 
## Kubernetes pause image, used for setting up shared
## namespaces in pods
case "${KUBE_VERSION}" in
  "1.29")
    SANDBOX_IMAGE_VERSION="3.8"
    ;;
  "1.30")
    SANDBOX_IMAGE_VERSION="3.9"
    ;;
  "1.31" | "1.32" | "1.33")
    SANDBOX_IMAGE_VERSION="3.10"
    ;;
  *)
    SANDBOX_IMAGE_VERSION=""
    ;;
esac

if [ -z ${SANDBOX_IMAGE_VERSION} ]; then
  echo "Sandbox image version could not be determined." 2>&1
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Set up containerd
echo "==> Setting up containerd..."

## Add required modules
echo "Adding required modules..."
cat <<EOMODCONF | tee /etc/modules-load.d/k8s-containerd.conf
overlay
br_netfilter
EOMODCONF

modprobe overlay
modprobe br_netfilter
echo "Done."

## Configure iptables
echo "Enabling iptables to see bridged traffic, and allow ip forwarding..."
cat <<EOSYSCTLCNF > /etc/sysctl.d/k8s-cri.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOSYSCTLCNF
sysctl --system
echo "Done."

## Install containerd
echo "Installing containerd..."
echo "------------------------"
echo "Adding official docker repository..."
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# shellcheck disable=SC1091
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update && apt-get install -y containerd.io
echo "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
echo "Setting cgroup driver to systemd"
sed --in-place 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

if [ -n "${SANDBOX_IMAGE_VERSION}" ]; then
  echo "Changing default sandbox image to registry.k8s.io/pause:${SANDBOX_IMAGE_VERSION}"
  SEDCMD="s/sandbox_image = \"registry.k8s.io\/pause:\([0-9]\{1,2\}\)\.\([0-9]\{1,2\}\)\"/sandbox_image = \"registry.k8s.io\/pause:${SANDBOX_IMAGE_VERSION}\"/g"
  sed --in-place "${SEDCMD}" /etc/containerd/config.toml
fi

echo "Starting containerd..."
systemctl restart containerd
echo "------------------------"
echo "Done."
echo

## Install kubelet, kubeadm, kubectl
echo "==> Installing kubelet, kubeadm and kubectl v${KUBE_VERSION}..."
echo "Adding kubernetes apt key from https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key..."
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "Done."
echo "Adding kubernetes apt repository..."
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
echo "Done."
echo "Installing..."
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
echo "Done."

## Add kubectl autocomplete
echo "Adding kubectl autocomplete..."
[ -d /etc/bash_completion.d ] || mkdir -p /etc/bash_completion.d
echo "Installing kubectl autocomplete..."
kubectl completion bash >/etc/bash_completion.d/kubectl
echo "Done."

