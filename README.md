# Kubernetes Practice Lab

This repository helps you spin up a 3-node Kubernetes cluster (1 control plane, 2 workers) using Terraform and Shell scripts. Perfect for DevOps engineers practicing Kubernetes in self-hosted environments.

## 🔧 Tech Stack

- AWS EC2 (Ubuntu 22.04 LTS)
- Terraform for infra provisioning
- kubeadm for cluster bootstrapping
- Calico as CNI
- Shell scripts for installing Docker, kubeadm, kubectl

---

## Installing kubeadm, kubelet and kubectl

You will install these packages on all of your machines:

- `kubeadm`: the command to bootstrap the cluster.
- `kubelet`: the component that runs on all of the machines in your cluster and does things like starting pods and containers.
- `kubectl`: the command line util to talk to your cluster.

Refer to official [kubernetes documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).

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
