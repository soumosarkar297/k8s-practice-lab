#!/bin/bash

set -e

k8s_version="v1.33.0"
hostname=$(hostname)

echo "Step 1: Pull Kubernetes images and init cluster"

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

echo "Step 2: Apply Calico Network"

# Apply Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/calico.yaml

# Remove control-plane taint so pods can be scheduled
kubectl taint nodes "$hostname" node-role.kubernetes.io/control-plane:NoSchedule-

echo "Step 3: Install Metrics Server"

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "Kubernetes cluster setup is complete!"
