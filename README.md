# Deploy a Kubernetes Cluster Kubeadm on Vagrant

This guide walks us through how to spin up a full Kubernetes cluster locally using Vagrant instead of cloud VMs 
making it cost-effective, lightweight, and fast to experiment with DevOps and Kubernetes concepts.

## Overview

We’ll use a single Vagrantfile to create:

- 1 Control Plane (Master) node

- 1 Worker node (can scale by increasing WORKER_NODE_COUNT)

Each node runs Ubuntu (Jammy 22.04) with the correct Kubernetes prerequisites.

Node	 CPU	 Memory	 Role
master	2	   2 GB	   Control Plane
worker	1	   1 GB	   Worker Node


### Step 1: Create your Vagrantfile

```
BASE_BOX_IMAGE = "ubuntu/jammy64"
CPUS_MASTER = 2
MEMORY_MASTER = 2048
CPUS_WORKER = 1
MEMORY_WORKER = 1024

# Change to increase number of workers
WORKER_NODE_COUNT = 1

Vagrant.configure("2") do |config|
  # Master node
  config.vm.define "master" do |master|
    master.vm.box = BASE_BOX_IMAGE
    master.vm.hostname = "master.example.com"
    master.vm.network "private_network", ip: "192.168.56.101"
    master.vm.network "forwarded_port", guest: 6443, host: 6443
    master.vm.provider "virtualbox" do |vb|
      vb.name = "master"
      vb.cpus = CPUS_MASTER
      vb.memory = MEMORY_MASTER
    end
  end

  # Worker node(s)
  (1..WORKER_NODE_COUNT).each do |i|
    config.vm.define "worker#{i}" do |worker|
      worker.vm.box = BASE_BOX_IMAGE
      worker.vm.hostname = "worker#{i}.example.com"
      worker.vm.network "private_network", ip: "192.168.56.11#{i}"
      worker.vm.provider "virtualbox" do |vb|
        vb.name = "worker#{i}"
        vb.cpus = CPUS_WORKER
        vb.memory = MEMORY_WORKER
      end
    end
  end
end
```

### Step 2: Spin Up the Virtual Machines

```
vagrant up
```
<img width="720" height="835" alt="Screenshot 2025-11-13 at 21 55 14" src="https://github.com/user-attachments/assets/be97176d-9773-4c25-bbbd-3abf8c30b9c6" />

Once the setup finishes, you’ll have two VMs running.

SSH into them from two terminals:

```
vagrant ssh master
vagrant ssh worker1
```
<img width="1675" height="283" alt="Screenshot 2025-11-13 at 22 15 10" src="https://github.com/user-attachments/assets/ab1d77b1-8aa7-4c19-b721-2a3a38ac9575" />

### Step 3: Common Setup (Both Master and Worker)

Create a file called common.sh and paste the following script.

This installs dependencies, container runtime, and Kubernetes components.

```
#!/bin/bash
set -e

# 1. Update & install dependencies
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 2. Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3. Enable kernel modules and sysctl settings
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# 4. Install container runtime (containerd)
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 5. Install kubeadm, kubelet and kubectl
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet
```

```
chmod 700 common.sh
```

Run this script on both master and worker nodes:

```
./common.sh
```
<img width="843" height="603" alt="Screenshot 2025-11-13 at 22 22 26" src="https://github.com/user-attachments/assets/c051f912-3c9d-4730-af9f-b0b99245bcef" />

<img width="843" height="632" alt="Screenshot 2025-11-13 at 22 23 05" src="https://github.com/user-attachments/assets/6692078c-4e45-414e-b93f-0eb09365668e" />


### Step 4: Initialize the Control Plane

On the master node, create and run master.sh:

```
#!/bin/bash
set -e

# Initialize Kubernetes
sudo kubeadm init --apiserver-advertise-address=192.168.56.101 --pod-network-cidr=10.244.0.0/16

# Set up kubectl access
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install CNI (Flannel)
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

```
chmod 700 master.sh
```

Note: The apiserver-advertise-address=192.168.56.101 is the priivate ip address of our master node on vagrant. You can get this through ip addr show 

```
./master.sh
```

Once initialization completes, kubeadm will output a kubeadm join command.
Copy it. You’ll need it for the worker node.

### Step 5: Join the Worker Node

On the worker node, paste and run the kubeadm join ... command printed on your master terminal.
Example:

```
sudo kubeadm join 192.168.56.101:6443 --token <token> \
--discovery-token-ca-cert-hash sha256:<hash>
```

After a short while, verify from the master:

```
kubectl get nodes
kubectl get pods -n kube-system
```

<img width="782" height="486" alt="Screenshot 2025-11-13 at 22 35 09" src="https://github.com/user-attachments/assets/5f5512a0-0f19-4b79-bad4-5fef5a127082" />

### Step 6: Test Your Cluster

We can now deploy any sample workload or clone our project repo and start applying Kubernetes manifests:

```
kubectl apply -f <your-app-deployment>.yaml
kubectl get pods -A
```

<img width="765" height="541" alt="Screenshot 2025-11-13 at 22 59 13" src="https://github.com/user-attachments/assets/89097e8b-0a34-4069-9e68-325467a16cdc" />


<img width="808" height="309" alt="Screenshot 2025-11-13 at 23 00 01" src="https://github.com/user-attachments/assets/d627d0d2-6adf-4c1a-abd6-091f708c8ca3" />


## Resetting the Cluster (Cleanup Script)

If you ever need to rebuild or reset your cluster, you can use a simple script called cleanup.sh.
It completely removes all Kubernetes components, data, and configuration files — making your node ready for a fresh setup.

Create cleanup.sh

```
#!/bin/bash
# cleanup.sh — Reset and clean up a kubeadm Kubernetes node
# Works for both master and worker nodes

set -e

echo "Cleaning up Kubernetes cluster components..."

# Step 1: Reset kubeadm configuration
sudo kubeadm reset -f

# Step 2: Stop kubelet and containerd
echo "Stopping kubelet and containerd..."
sudo systemctl stop kubelet || true
sudo systemctl stop containerd || true

# Step 3: Remove Kubernetes and CNI directories
echo "🗑️  Removing Kubernetes and CNI directories..."
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /var/lib/etcd/
sudo rm -rf /etc/cni/
sudo rm -rf /var/lib/cni/
sudo rm -rf /opt/cni/

# Step 4: Remove kube config for the current user
echo "Removing kube config..."
rm -rf $HOME/.kube

# Step 5: Restart containerd and kubelet
echo "Restarting containerd and kubelet..."
sudo systemctl restart containerd || true
sudo systemctl restart kubelet || true

echo "Cleanup completed successfully!"
echo "You can now reinitialize the master node with:"
echo "  sudo kubeadm init --apiserver-advertise-address=<your-master-ip> --pod-network-cidr=10.244.0.0/16"
echo ""
echo "Or rejoin the worker node using your previous kubeadm join command."
```

Run the cleanup

```
chmod +x cleanup.sh
./cleanup.sh
```
<img width="845" height="480" alt="Screenshot 2025-11-13 at 23 07 44" src="https://github.com/user-attachments/assets/4646d06d-f044-47ad-8180-eb70f179c8f9" />



