#!/bin/bash

set -e

echo "=== Mise à jour du système ==="
sudo apt-get update
sudo apt-get upgrade -y

echo "=== Désactivation du swap ==="
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "=== Configuration des modules kernel ==="
cat <<EOF2 | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF2

sudo modprobe overlay
sudo modprobe br_netfilter

echo "=== Configuration sysctl ==="
cat <<EOF2 | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF2

sudo sysctl --system

echo "=== Installation des dépendances ==="
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

echo "=== Installation de containerd ==="
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
echo "=== Fix du sandbox image (pause:3.10.1) ==="
sudo sed -i 's#sandbox_image = "registry.k8s.io/pause:.*"#sandbox_image = "registry.k8s.io/pause:3.10.1"#' /etc/containerd/config.toml


sudo systemctl restart containerd
sudo systemctl enable containerd

echo "=== Installation de kubeadm, kubelet et kubectl ==="
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet

echo 'source <(kubectl completion bash)' >>~/.bashrc

echo "=== Installation terminée pour les composants communs ==="
