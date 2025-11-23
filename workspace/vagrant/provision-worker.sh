#!/bin/bash

set -e

echo "=== Préparation du stockage local ==="
sudo mkdir -p /mnt/k8s-storage
sudo chmod -R 777 /mnt/k8s-storage/

# Créer les répertoires spécifiques selon le worker
if [[ $(hostname) == "k8s-worker1" ]]; then
  sudo mkdir -p /mnt/k8s-storage/{postgres-devops,jenkins,nexus,portainer,postgres-staging}
elif [[ $(hostname) == "k8s-worker2" ]]; then
  sudo mkdir -p /mnt/k8s-storage/{sonarqube,minio,postgres-production}
fi

echo "=== Attente de la commande join ==="
while [ ! -f /vagrant/join.sh ]; do
  echo "Attente de join.sh..."
  sleep 5
done

echo "=== Exécution de la commande join ==="
bash /vagrant/join.sh

echo "=== Worker prêt ==="
