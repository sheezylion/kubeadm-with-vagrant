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