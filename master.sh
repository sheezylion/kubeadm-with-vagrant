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
