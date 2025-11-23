# Configuration de l'environnement de travail avec Vagrant

Ce document décrit comment configurer un environnement de développement Kubernetes local en utilisant Vagrant pour le projet k8s-infras.

## Prérequis

Avant de commencer, assurez-vous d'avoir installé :

- **Vagrant** (version 2.2+ recommandée)
- **VirtualBox** (ou un autre provider supporté par Vagrant)
- **Ressources système** :
  - Au moins 20 GB de RAM disponible
  - 50 GB d'espace disque libre
  - Processeur avec virtualisation activée

## Architecture de l'environnement Vagrant

L'environnement crée 3 machines virtuelles :

- **k8s-master** : Nœud master Kubernetes (2 CPUs, 4 GB RAM, 10 GB disque)
- **k8s-worker1** : Nœud worker 1 (1 CPU, 2 GB RAM, 10 GB disque)
- **k8s-worker2** : Nœud worker 2 (1 CPU, 2 GB RAM, 10 GB disque)

Toutes les VMs utilisent Ubuntu 22.04 LTS et sont connectées via un réseau privé.

## Installation et démarrage

1. **Naviguer vers le répertoire du projet** :
   ```bash
   cd /path/to/k8s-infras
   ```

2. **Démarrer les machines virtuelles** :
   ```bash
   vagrant up
   ```

   Cette commande va :
   - Télécharger la box Ubuntu 22.04 si nécessaire
   - Créer les 3 VMs
   - Provisionner automatiquement Kubernetes sur chaque nœud
   - Installer Calico comme CNI
   - Configurer le stockage local

   Le processus peut prendre 15-30 minutes selon votre connexion internet et ressources.

3. **Vérifier l'état des VMs** :
   ```bash
   vagrant status
   ```

## Accès au cluster

### Connexion SSH aux VMs

- **Master** :
  ```bash
  vagrant ssh k8s-master
  ```

- **Worker 1** :
  ```bash
  vagrant ssh k8s-worker1
  ```

- **Worker 2** :
  ```bash
  vagrant ssh k8s-worker2
  ```

### Utilisation de kubectl

Sur le master, kubectl est déjà configuré :

```bash
vagrant ssh k8s-master
kubectl get nodes
kubectl get pods -n kube-system
```

Pour utiliser kubectl depuis votre machine hôte, copiez le fichier de configuration :

```bash
# Depuis le répertoire du projet
mkdir -p ~/.kube
vagrant ssh k8s-master -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config-vagrant
export KUBECONFIG=~/.kube/config-vagrant
kubectl get nodes
```

## Synchronisation des fichiers

Le répertoire `/vagrant` dans chaque VM est synchronisé avec le répertoire du projet sur l'hôte. Vous pouvez :

- Éditer les fichiers YAML sur votre machine hôte
- Les appliquer directement depuis les VMs :
  ```bash
  vagrant ssh k8s-master
  kubectl apply -f /vagrant/namespaces/
  kubectl apply -f /vagrant/base/storage/
  ```

## Déploiement de l'infrastructure

Une fois le cluster opérationnel, suivez le guide de déploiement initial :

```bash
# Créer les namespaces
kubectl apply -f namespaces/

# Déployer le stockage
kubectl apply -f base/storage/

# Créer les secrets (éditez-les d'abord avec vos valeurs)
kubectl apply -f base/secrets/

# Déployer les services
kubectl apply -f infrastructure/postgres/
kubectl apply -f infrastructure/jenkins/
# etc.
```

Ou utilisez les scripts automatisés :

```bash
./scripts/deploy-all.sh
```

## Gestion de l'environnement

### Arrêter les VMs (sans les détruire)
```bash
vagrant halt
```

### Redémarrer les VMs
```bash
vagrant up
```

### Détruire l'environnement (attention : données perdues)
```bash
vagrant destroy
```

### Recréer une VM spécifique
```bash
vagrant destroy k8s-worker1
vagrant up k8s-worker1
```

## Dépannage

### Les VMs ne démarrent pas
- Vérifiez que VirtualBox est installé et fonctionnel
- Assurez-vous que la virtualisation est activée dans le BIOS
- Vérifiez les ressources disponibles

### Problèmes de réseau
- Les VMs utilisent DHCP sur un réseau privé VirtualBox
- Si les nœuds ne se voient pas, vérifiez `vagrant ssh k8s-master -- ip addr`

### Problèmes Kubernetes
- Consultez les logs : `kubectl logs -n kube-system`
- Vérifiez l'état des pods : `kubectl get pods -n kube-system`
- Redémarrez kubelet si nécessaire : `sudo systemctl restart kubelet`

### Reprovisionner sans recréer
```bash
vagrant provision
```

## Personnalisation

Vous pouvez modifier le `Vagrantfile` pour :
- Changer les ressources allouées
- Ajouter des VMs supplémentaires
- Modifier la configuration réseau
- Ajouter des provisions supplémentaires

Après modification, rechargez la configuration :
```bash
vagrant reload
```

## Sécurité

Cet environnement est destiné au développement uniquement :
- N'utilisez pas en production
- Les secrets sont en clair dans les fichiers YAML
- Aucun firewall avancé configuré

Pour la production, consultez les bonnes pratiques dans `docs/04-best-practices.md`.
