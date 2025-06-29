#!/bin/bash

set -e

k8s_version="v1.33.0"
hostname=$(hostname)

echo "Step 1: Install kubectl, kubeadm, and kubelet ${k8s_version}"

# Install dependencies
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Prepare keyrings
sudo mkdir -p /etc/apt/keyrings

# Kubernetes repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update and install Kubernetes components
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "Step 2: Swap Off and Kernel Modules Setup"

# Disable swap
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

# Load kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Persist kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# Kernel parameters for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params
sudo sysctl --system

echo "Step 3: Install and Configure Containerd"

# Check if containerd is already installed
if ! command -v containerd &>/dev/null; then
  echo "Containerd not found, installing..."

  # Add Docker repo key and repository
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg

  echo \
    "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update -y

  # 👇 THIS is the important line
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confold" \
    --allow-downgrades --allow-change-held-packages containerd.io
else
  echo "Containerd is already installed, skipping installation."
fi

# Always configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# Modify config.toml to use SystemdCgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# Enable kubelet
sudo systemctl enable kubelet

echo "Step 4: Pull Kubernetes images and init cluster"

# Pull Kubernetes images
sudo kubeadm config images pull --cri-socket unix:///run/containerd/containerd.sock --kubernetes-version ${k8s_version}

# Initialize cluster
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --upload-certs \
  --kubernetes-version=${k8s_version} \
  --control-plane-endpoint="$hostname" \
  --ignore-preflight-errors=all \
  --cri-socket unix:///run/containerd/containerd.sock

# Setup kubeconfig for user
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
export KUBECONFIG=$HOME/.kube/config

echo "Step 5: Apply Calico Network"

# Apply Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/calico.yaml

# Remove control-plane taint so pods can be scheduled
kubectl taint nodes "$hostname" node-role.kubernetes.io/control-plane:NoSchedule-

echo "Step 6: Install Metrics Server"

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "Kubernetes cluster setup is complete!"
