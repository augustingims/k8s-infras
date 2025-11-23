#!/bin/bash

set -e

echo "=== Initialisation du cluster Kubernetes sur le master ==="

# Récupérer l'IP du master (get ip : $(hostname -I | awk '{print $2}'))
MASTER_IP=192.168.56.101
echo "IP du master: $MASTER_IP"

# Initialiser le cluster
sudo kubeadm init --node-name $HOSTNAME \
  --apiserver-advertise-address=$MASTER_IP \
  --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint=$MASTER_IP

# Configurer kubectl pour l'utilisateur vagrant
mkdir -p /home/vagrant/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config

# Configurer kubectl pour root aussi (pour les scripts)
sudo mkdir -p /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config

echo "=== Installation du réseau Flannel ==="
sudo kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "=== Génération de la commande join ==="
JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)
echo "#!/bin/bash" > /vagrant/join.sh
echo "sudo $JOIN_COMMAND" >> /vagrant/join.sh
chmod +x /vagrant/join.sh

echo "=== Installation de Helm ==="
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "=== Vérification du cluster ==="
kubectl get nodes

echo "=== Master prêt ==="
