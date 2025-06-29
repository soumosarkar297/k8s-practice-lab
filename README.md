# Kubernetes Practice Lab

This repository helps you spin up a 3-node Kubernetes cluster (1 control plane, 2 workers) using Terraform and Shell scripts. Perfect for DevOps engineers practicing Kubernetes in self-hosted environments.

---

## 🚀 Project Structure

```bash
k8s-practice-lab/
├── .gitignore
├── README.md  <-- you are here
├── terraform/             # Infrastructure code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── scripts/               # Bash setup scripts
│   ├── kube-install.sh
│   ├── kube-init-control-plane.sh
│   └── kube-join-worker.sh
└── manifests/             # Kubernetes manifests
    ├── calico.yaml
    └── nginx-sample.yaml
```

---

## 🔧 Tech Stack

- AWS EC2 (Ubuntu 24.04 LTS)
- Linux environment (Mac / WSL / Linu)
- Terraform for infra provisioning
- kubeadm for cluster bootstrapping
- Calico as CNI
- Shell scripts for installing containerd, kubeadm, kubectl

---

## Setup Kubernetes Cluster Lab

## 🧰 Prerequisites

### 1. Install Terraform

Follow [Terraform installation docs](https://developer.hashicorp.com/terraform/install) or use below for Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y gnupg software-properties-common wget

wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform -y
```

Verify:

```bash
terraform -v
```

### 2. SSH Key Setup (If Not Present)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

This generates:

- `~/.ssh/id_rsa` (private key)
- `~/.ssh/id_rsa.pub` (public key)

Ensure `~/.ssh/id_rsa.pub` is used in Terraform:

```hcl
resource "aws_key_pair" "k8s_key" {
  key_name   = var.key_name
  public_key = file("~/.ssh/id_rsa.pub")
}
```

### 3. AWS Access Keys

To provision EC2 instances, set up AWS credentials:

Go to **IAM → Users → Security credentials → Create Access Key**.

Add the following to your Terraform variables file (`terraform/terraform.tfvars`):

```hcl
key_name       = "k8s-key"
aws_access_key = "<your-access-key>"
aws_secret_key = "<your-secret-key>"
region         = "ap-south-1"  # Or any AWS region
ami_id         = "ami-020cba7c55df1f615"  # specify your AMI ID
```

---

## Installing kubeadm, kubelet and kubectl

You will install these packages on all of your machines:

- `kubeadm`: the command to bootstrap the cluster.
- `kubelet`: the component that runs on all of the machines in your cluster and does things like starting pods and containers.
- `kubectl`: the command line util to talk to your cluster.

Refer to official [kubernetes documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).

---

## ⚙️ Provision Infrastructure

```bash
git clone https://github.com/<your-username>/k8s-practice-lab.git
cd k8s-practice-lab/infra

terraform init
terraform apply
```

Terraform will provision 3 EC2 instances:

- 1 Control Plane Node
- 2 Worker Nodes

Output will include their public IPs.

---

## 🔧 Control Plane Setup (on the master node)

### Step 1: SSH into Control Plane EC2

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<control-plane-public-ip>
```

### Step 2: Run Setup Script

Run the [`kube-install.sh`](./scripts/kube-install.sh) script

```bash
sudo su
nano setup.sh
chmod +x setup.sh
sh setup.sh
```

### Step 3: Initialize the Control Plane

Run the [`kube-init-control-plane.sh`](./scripts/kube-init-control-plane.sh) script

```bash
nano kube-init.sh
chmod +x kube-init.sh
sh kube-init.sh
```

This will:

- Run `kubeadm init`
- Configure `kubectl`
- Install Calico CNI and Metrics Server
- Untaint the control plane (optional)

✅ You'll now have a functioning control plane.

---

## 🛑 ⚠️ Important: Worker Nodes Should NOT Run These

If you're working on a **worker node**, **DO NOT RUN**:

- `kube-init-control-plane.sh`
- OR, `kubeadm init`

These are control-plane specific. Worker nodes should follow the section below.

---

## 🧱 Worker Node Setup

### Step 1: SSH into Worker Node EC2

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<worker-node-public-ip>
```

### Step 2: Install Kubernetes Components

Run the [`kube-install.sh`](./scripts/kube-install.sh):

- Disable swap
- Install containerd
- Install kubelet, kubeadm
- Optionally install kubectl

### Step 3: Get Join Command

From the **control plane**, run:

```bash
kubeadm token create --print-join-command
```

**Important**: Append `--cri-socket` if using containerd:

```bash
--cri-socket unix:///run/containerd/containerd.sock
```

### Step 4: Join the Cluster

```bash
sudo kubeadm join <control-plane-ip>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --cri-socket unix:///run/containerd/containerd.sock
```

---

## ✅ Verify Cluster

On the control plane:

```bash
kubectl get nodes
```

You should see:

- `control-plane` → Ready
- `worker-node-1` → Ready
- `worker-node-2` → Ready

---

## ✅ Summary Checklist

- Terraform installed ✅
- AWS access key created ✅
- SSH key generated ✅
- Infrastructure provisioned with Terraform ✅
- Control plane installed and initialized ✅
- Workers joined to cluster ✅
- `kubectl get nodes` shows all as Ready ✅

---

## 🧠 Bonus: Reset Worker Node (If Misconfigured)

```bash
sudo kubeadm reset --cri-socket unix:///run/containerd/containerd.sock --force
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet/* /etc/cni/net.d
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

---

## CNI (Container Network Interface)

CNI stands for Container Network Interface. It's a **standard interface specification** developed by the Cloud Native Computing Foundation (CNCF) that allows different networking solutions (plugins) to integrate with container runtimes (like Kubernetes, containerd, or CRI-O).

- Provisioning and managing an IP address
- IP-per-container assignment

CNI ensures that when a pod is created:

- It gets a network interface (e.g., eth0).
- It’s assigned an IP.
- Routes are added so it can communicate with other pods/services.

> Kubernetes doesn’t handle networking on its own—it delegates it to **CNI plugins** like Flannel, Calico, Weave, etc.

| Feature                  | **Flannel**                                  | **Calico**                                     |
| ------------------------ | -------------------------------------------- | ---------------------------------------------- |
| **Type**                 | Overlay network                              | Pure Layer 3 network (no overlay by default)   |
| **Network Mode**         | VXLAN (default), also supports host-gw       | BGP (default), VXLAN (optional)                |
| **Performance**          | Moderate (due to encapsulation overhead)     | High (no encapsulation in default mode)        |
| **Policy Support**       | ❌ Basic or none                             | ✅ Advanced network policy engine              |
| **Use Case**             | Simpler setups, less need for security rules | Complex clusters with strict security policies |
| **IPAM (IP Management)** | Basic                                        | Advanced CIDR and IP pool control              |
| **Firewall Integration** | ❌ Not integrated                            | ✅ Integrates with iptables and eBPF           |
| **Ease of Setup**        | Very simple to set up                        | Slightly more complex due to policy features   |

---
