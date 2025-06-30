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

## 📊 Metrics Server Issue (Fix Guide)

### ❌ Problem

If the metrics-server pod shows this:

```bash
kubectl get pods -n kube-system

...
metrics-server-xxxx  0/1 Running
```

And logs show:

```bash
kubectl logs -n kube-system metrics-server-xxxx

...
x509: cannot validate certificate for <IP> because it doesn't contain any IP SANs
```

### 🛠️ Solution: Use Insecure TLS + InternalIP for Kubelet

#### Step 1: Edit the metrics-server deployment

```bash
kubectl edit deployment metrics-server -n kube-system
```

Look for the `spec.template.spec.containers[0].args:` section and update it to:

```yaml
        args:
          - --cert-dir=/tmp
          - --secure-port=4443
          - --kubelet-preferred-address-types=InternalIP
          - --kubelet-insecure-tls
```

These flags:

- `--kubelet-insecure-tls`: Skips kubelet TLS verification (required for kubeadm setups)
- `--kubelet-preferred-address-types=InternalIP`: Use EC2 private IPs instead of hostnames

#### Step 2: Force a rollout restart

```bash
kubectl rollout restart deployment metrics-server -n kube-system
```

#### Finally test

```bash
kubectl get nodes -A
kubectl top nodes
kubectl top pods -A
```

---

## Core Concepts Practical

### View your Kubeconfig file

```bash
kubectl config view
```

This file (usually located at `~/.kube/config`) tells `kubectl` how to connect to your Kubernetes cluster.

### GVK (Group-Version-Kind) and GVR (Group-Version-Resource)

- GVK identifies the **type of a Kubernetes resource**. GVK is used in object definitions and controller logic.
- GVR identifies the **API endpoint** used to *access the resource*. GVR is used by API clients and for REST path discovery (`/apis/<group>/<version>/<resources>`).

| Component    | Meaning                                                                        |
| -----------  | ------------------------------------------------------------------------------ |
| **Group**    | The API group the resource belongs to (e.g., `apps`, `batch`, `""` for core)   |
| **Version**  | The version of the API (e.g., `v1`, `v1beta1`)                                 |
| **Kind**     | The type of object (e.g., `Pod`, `Deployment`, `Service`)                      |
| **Resource** | The plural name used in the REST API (e.g., `deployments`, `pods`, `services`) |

> Plural of **kind** used for rest calls → calling API endpoints to interact with objects

#### Example of GVK

```yaml
apiVersion: apps/v1
kind: Deployment
```

- **Group** = apps
- **Version** = v1
- **Kind** = Deployment

→ So the **GVK is**: apps/v1, Kind=Deployment

This is used in manifests and controller logic.

#### Example of GVR

For a Deployment:

- **Group** = apps
- **Version** = v1
- **Resource** = deployments

→ So **GVR is**: apps/v1, Resource=deployments

### List all available groups in the cluster

```bash
kubectl api-versions
```

### Resources & Kinds

- **Resource**: The plural, REST-facing name (e.g., `pods`, `deployments`, `services`).
- **Kind**: The singular, human-readable name in manifests (e.g., `Pod`, `Deployment`, `Service`).

Example mapping:

```yaml
apiVersion: apps/v1
kind: Deployment
```

→ Group `apps`, Version `v1`, Kind `Deployment`; API Resource is `deployments`

### Discovering Resources

```bash
kubectl api-resources -o wide
```

### API Calls (REST Verbs)

Kubernetes supports standard REST actions on resources:

| Verb     | Description                 |
| -------- | --------------------------- |
| `GET`    | Read a resource or list     |
| `POST`   | Create a new resource       |
| `PUT`    | Update/replace a resource   |
| `PATCH`  | Modify part of a resource   |
| `DELETE` | Remove a resource           |
| `WATCH`  | Stream changes to resources |

---

## Create a New Kubernetes User with Client Certificates

We'll create a new user with a certificate-based authentication method and give them access using RBAC.

### Step 1: Generate a Certificate for the User

```bash
# Create private key
openssl genrsa -out supersection.key 2048

# Create a certificate signing request
openssl req -new -key supersection.key -out supersection.csr -subj "/CN=supersection/O=dev-team"

cat supersection.csr | base64 | tr -d '\n'
# Paste the output in CertificateSigningRequest
```

Then `kubectl apply` the [`certificate-signing-request.yaml`](./manifests/certificate-signing-request.yaml)

```bash
vi csr.yaml

kubectl apply -f csr.yaml

kubectl certificate approve supersection

kubectl get csr supersection -o jsonpath='{.status.certificate}' | base64 --decode > supersection.crt
```

### Create RBAC Role/Binding for the User

Create a `Role` or `ClusterRole`, and bind the user using `RoleBinding` or `ClusterRoleBinding`.

Now `kubectl apply` the [`role-binding.yaml`](./manifests/role-binding.yaml)

```bash
vi role-rb.yaml

kubectl apply -f role-rb.yaml
```

### Configure kubeconfig for the New User

Create a new context in your kubeconfig using this new cert:

```bash
kubectl config set-credentials supersection --client-certificate=supersection.crt --client-key=supersection.key

kubectl config set-context supersection-context --cluster=kubernetes --namespace=default --user=supersection
```

### Test Access

Now you can switch between contexts:

```bash
kubectl config get-contexts

kubectl config use-context supersection-context

kubectl get pods
kubectl get deploy
```

Verify current context:

```bash
kubectl config current-context
```

---

## Serviceaccunt Practical

```bash
kubectl create deployment nginx --image=nginx --dry-run=client -o json > nginx-deploy.json

kubectl create serviceaccount super --namespace default

kubectl create clusterrolebinding super-clusteradmin-binding --clusterrole=cluster-admin --serviceaccount=default:super

TOKEN=$(kubectl create token super)

API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
```

Now let's do the API interaction:

```bash
curl -X GET ${API_SERVER}/apis/apps/v1/namespaces/default/deployments \
  -H "Authorization: Bearer $TOKEN" \
  -k

curl -X GET ${API_SERVER}/api/v1/namespaces/default/pods \
  -H "Authorization: Bearer $TOKEN" \
  -k

curl -X POST ${API_SERVER}/apis/apps/v1/namespaces/default/deployments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @nginx-deploy.json \
  -k

kubectl get deploy

curl -X GET ${API_SERVER}/apis/apps/v1/namespaces/default/deployments \
  -H "Authorization: Bearer $TOKEN" \
  -k
```

---

## Kubernetes Architecture

## Core Components

### 1. API Server (`kube-apiserver`)

The API Server is the front door to your Kubernetes cluster. It’s a RESTful service that processes requests (from `kubectl`, other components, or CI/CD tools).

#### Responsibilities

- **Authentication**: Validates who is making the request (e.g., token, certificate, OIDC).

- **Authorization**: Determines what the authenticated user is allowed to do (via RBAC, ABAC, or Webhooks).

- **Admission Controllers**: Final gatekeepers before persisting objects. They can:
  - **Validate** requests (e.g., resource quota)
  - **Mutate** requests (e.g., inject labels, sidecars)

#### How API Server works

1. A request is made to create a pod (`kubectl apply -f pod.yaml`)
2. User is authenticated with the headers (certs, bearer token) passed
3. Authorization via RBAC confirms the user has `create` rights on `pods`
4. Admission Webhooks validate/mutate the pod spec
5. The request is passed to `etcd` (the storage backend)
6. The `kube-scheduler` and `kubelet` take action to deploy the pod

### 2. etcd

- **Key-value store** for distributed systems, used as the cluster’s backing store.
- API Server writes to it.
- Stores all **cluster state** (nodes, pods, configs, secrets, etc.)
- Highly available and consistent via the **Raft** consensus algorithm

> 🔐 Secrets are stored here—ensure encryption at rest is enabled.

### 3. Controller Manager

- Contains various **controllers** (e.g., replication, endpoints, namespace, node)
- Watches the current state in etcd and makes changes to move towards the desired state

#### Example of Controller Manager

If a Deployment requires 3 pods and only 2 are running, the ReplicaSet controller will create 1 more pod.

### 4. Scheduler (`kube-scheduler`)

- Watches for unscheduled pods (i.e., no assigned node)
- Selects the best node for the pod based on:
  - CPU/memory availability
  - Taints & tolerations
  - Node affinity
  - Custom scheduling policies

## Node Components

### 1. kubelet

- An agent running on each node
- Receives instructions from the API Server
- Ensures containers are running as specified in PodSpecs

### 2. Container Runtime

- Responsible for running containers
- Popular choices: containerd, CRI-O, Docker (deprecated in latest versions)

### 3. kube-proxy

- Manages network rules and forwarding on each node
- Configures networking so the pod is reachable within the cluster
- Supports:
  - Services
  - Load balancing (via `iptables` or `ipvs`)

> Every time a pod is created, the ip table is handled by kube-proxy

---

## CRI (Container Runtime Interface)

CRI stands for Container Runtime Interface, which is a **Kubernetes-defined API** that lets the `kubelet` (agent on each node) talk to the container runtime to:

- Create / manage containers
- Pull images
- Manage volumes
- Handle networking

> CRI acts like an abstraction layer between `kubelet` and container runtimes.

### Workflow of `kubelet` via CRI

kubelet → CRI → containerd → containerd-shim → runc

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
