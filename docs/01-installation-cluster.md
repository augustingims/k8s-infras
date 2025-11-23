# Installation du Cluster Kubernetes

## 📋 Vue d'ensemble

Ce guide vous accompagne dans l'installation d'un cluster Kubernetes avec 1 master et 2 workers.

## 🖥️ Configuration matérielle requise

### Master Node
- **CPU**: 2 cores minimum (4 cores recommandé)
- **RAM**: 4 GB minimum (8 GB recommandé)
- **Stockage**: 50 GB minimum
- **OS**: Ubuntu 22.04 LTS

### Worker Nodes (x2)
- **CPU**: 4 cores minimum
- **RAM**: 8 GB minimum (16 GB recommandé)
- **Stockage**: 100 GB minimum
- **OS**: Ubuntu 22.04 LTS

## 🚀 Installation

### 1. Préparation des nœuds (sur tous les nœuds)

```bash
# Mettre à jour le système
sudo apt-get update
sudo apt-get upgrade -y

# Désactiver le swap (requis par Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configurer les modules kernel
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configurer les paramètres sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Installer les dépendances
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
```

### 2. Installation de containerd (sur tous les nœuds)

```bash
# Installer containerd
sudo apt-get install -y containerd

# Configurer containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Activer SystemdCgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
echo "=== Fix du sandbox image (pause:3.10.1) ==="
sudo sed -i 's#sandbox_image = "registry.k8s.io/pause:.*"#sandbox_image = "registry.k8s.io/pause:3.10.1"#' /etc/containerd/config.toml
# Redémarrer containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### 3. Installation de kubeadm, kubelet et kubectl (sur tous les nœuds)

```bash
# Ajouter la clé GPG de Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Ajouter le repository Kubernetes
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

# Installer kubeadm, kubelet et kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Activer kubelet
sudo systemctl enable kubelet
```

### 4. Initialisation du Master Node

```bash
# Sur le master node uniquement
# Récupérer l'IP du master
MASTER_IP=$(hostname -I | awk '{print $1}')

# Initialiser le cluster
sudo kubeadm init \
  --apiserver-advertise-address=$MASTER_IP \
  --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint=$MASTER_IP

# Configurer kubectl pour l'utilisateur courant
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Vérifier l'installation
kubectl get nodes
```

### 5. Installation du CNI (Flannel)

```bash
# Sur le master node
# Installer Flannel
sudo kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### 6. Joindre les Worker Nodes

```bash
# Sur le master, récupérer la commande de join
kubeadm token create --print-join-command

# Sur chaque worker node, exécuter la commande retournée
# Exemple:
sudo kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>

# Vérifier sur le master que les workers ont rejoint
kubectl get nodes
```

### 7. Labelliser les nœuds

```bash
# Sur le master
# Identifier les nœuds
kubectl get nodes

# Labelliser les workers
kubectl label nodes <worker1-name> node-role.kubernetes.io/worker=worker
kubectl label nodes <worker2-name> node-role.kubernetes.io/worker=worker

# Labelliser pour le stockage
kubectl label nodes <worker1-name> storage=local
kubectl label nodes <worker2-name> storage=local
```

### 8. Installation de Helm

```bash
# Sur le master node
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Vérifier l'installation
helm version
```

### 9. Préparation du stockage local

```bash
# Sur worker1
ssh worker1
sudo mkdir -p /mnt/k8s-storage/{postgres-devops,jenkins,nexus,portainer,postgres-staging}
sudo chmod -R 777 /mnt/k8s-storage/

# Sur worker2
ssh worker2
sudo mkdir -p /mnt/k8s-storage/{sonarqube,minio,postgres-production}
sudo chmod -R 777 /mnt/k8s-storage/
```

## ✅ Vérification de l'installation

```bash
# Vérifier les nœuds
kubectl get nodes

# Vérifier les pods système
kubectl get pods -n kube-system

# Vérifier les composants
kubectl get componentstatuses

# Tester le déploiement d'un pod
kubectl run nginx --image=nginx
kubectl get pods
kubectl delete pod nginx
```

## 🔧 Configuration optionnelle

### Activer l'auto-complétion

```bash
# Pour bash
echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc
source ~/.bashrc
```

### Installer Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patcher pour ignorer les certificats TLS (dev uniquement)
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

## 🐛 Troubleshooting

### Les nœuds ne sont pas Ready

```bash
# Vérifier les logs kubelet
sudo journalctl -u kubelet -f

# Vérifier le CNI
kubectl get pods -n kube-system
```

### Problème de réseau

```bash
# Vérifier les routes
ip route

# Vérifier iptables
sudo iptables -L -n -v
```

## 📚 Références

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)

