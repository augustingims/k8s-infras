# Scripts d'automatisation

## 📋 Vue d'ensemble

Ce dossier contient des scripts bash pour automatiser le déploiement de l'infrastructure Kubernetes.

## 📁 Scripts disponibles

### deploy-all.sh
Script de déploiement complet de l'infrastructure.

**Usage** :
```bash
./deploy-all.sh [--skip-ingress] [--skip-apps]
```

**Options** :
- `--skip-ingress` : Ne pas installer l'Ingress Controller
- `--skip-apps` : Ne pas déployer les applications

**Ce qu'il fait** :
1. Vérifie les prérequis (kubectl, connexion au cluster)
2. Crée les namespaces
3. Configure le stockage (StorageClass, PV)
4. Crée les secrets et ConfigMaps
5. Déploie l'infrastructure DevOps (PostgreSQL, Jenkins, Nexus, etc.)
6. Affiche un résumé du déploiement

**Exemple** :
```bash
# Déploiement complet
./deploy-all.sh

# Déploiement sans les applications
./deploy-all.sh --skip-apps

# Déploiement sans Ingress (pour tests locaux)
./deploy-all.sh --skip-ingress
```

### cleanup.sh
Script de nettoyage complet de l'infrastructure.

**⚠️ ATTENTION** : Ce script supprime TOUTES les ressources déployées, y compris les données !

**Usage** :
```bash
./cleanup.sh [--force]
```

**Options** :
- `--force` : Pas de confirmation interactive

**Ce qu'il fait** :
1. Supprime l'infrastructure DevOps
2. Supprime les ConfigMaps et Secrets
3. Supprime les PVC et PV
4. Supprime les namespaces

**Exemple** :
```bash
# Avec confirmation
./cleanup.sh

# Sans confirmation (automatisation)
./cleanup.sh --force
```

**Note** : Les données sur les nœuds (`/mnt/k8s-storage/`) ne sont pas supprimées automatiquement.

### health-check.sh
Script de vérification de santé du cluster.

**Usage** :
```bash
./health-check.sh [--detailed]
```

**Options** :
- `--detailed` : Affiche des informations détaillées

**Ce qu'il fait** :
1. Vérifie l'état des nodes
2. Vérifie les pods en erreur
3. Vérifie les pods par namespace
4. Vérifie les PersistentVolumeClaims
5. Vérifie les services critiques
6. Affiche l'utilisation des ressources
7. Affiche les événements récents (Warning/Error)
8. Affiche un résumé global

**Exemple** :
```bash
# Health check rapide
./health-check.sh

# Health check détaillé
./health-check.sh --detailed
```

**Codes de sortie** :
- `0` : Cluster en bonne santé
- `1` : Cluster nécessite une attention

## 🚀 Utilisation

### Préparation

```bash
# Rendre les scripts exécutables
cd k8s-infras/scripts
chmod +x *.sh

# Vérifier kubectl
kubectl version
kubectl cluster-info
```

### Déploiement initial

```bash
# 1. Déployer l'infrastructure complète
./deploy-all.sh

# 2. Vérifier le déploiement
kubectl get pods --all-namespaces

# 3. Configurer les services (voir docs/03-configuration-services.md)
```

### Mise à jour

```bash
# Mettre à jour une partie spécifique
kubectl apply -f ../infrastructure/jenkins/deployment.yaml

# Ou redéployer complètement
./cleanup.sh
./deploy-all.sh
```

## 🔧 Personnalisation

### Modifier les scripts

Les scripts sont conçus pour être facilement personnalisables :

**Variables en haut du script** :
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"
```

**Fonctions réutilisables** :
```bash
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
```

### Créer vos propres scripts

Exemple de script personnalisé :

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

# Votre logique ici
kubectl apply -f "$K8S_DIR/custom/my-resource.yaml"
```

## 📊 Scripts additionnels suggérés

### restore.sh
Restaurer depuis un backup.

```bash
#!/bin/bash
BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file.tar.gz>"
    exit 1
fi

# Extraire
tar -xzf "$BACKUP_FILE"

# Restaurer les manifests
kubectl apply -f k8s-backup-*/

# Restaurer les bases de données
kubectl exec -i postgres-0 -n devops -- psql -U postgres < databases/devops-postgres.sql
```

### scale-apps.sh
Scaler les applications.

```bash
#!/bin/bash
REPLICAS=${1:-2}

kubectl scale deployment jenkins-agent -n devops --replicas=$REPLICAS
```

### health-check.sh
Vérifier la santé de l'infrastructure.

```bash
#!/bin/bash

echo "=== Nodes ==="
kubectl get nodes

echo "=== Pods DevOps ==="
kubectl get pods -n devops
```

## 🐛 Troubleshooting

### Script échoue avec "Permission denied"

```bash
chmod +x *.sh
```

### Script ne trouve pas kubectl

```bash
# Vérifier que kubectl est dans le PATH
which kubectl

# Ou utiliser le chemin complet
/usr/local/bin/kubectl version
```

### Script échoue à mi-parcours

Les scripts utilisent `set -e` pour s'arrêter en cas d'erreur. Vérifiez :

```bash
# Les logs du script
./deploy-all.sh 2>&1 | tee deploy.log

# Les événements Kubernetes
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

## 📚 Bonnes pratiques

1. **Toujours tester en staging** avant de déployer en production
2. **Faire un backup** avant toute modification majeure
3. **Versionner les scripts** dans Git
4. **Documenter les modifications** dans les commits
5. **Utiliser des variables** pour les valeurs configurables
6. **Logger toutes les actions** pour faciliter le debugging
7. **Implémenter des rollbacks** en cas d'échec

## 📝 Checklist de déploiement

- [ ] Cluster Kubernetes opérationnel
- [ ] kubectl configuré et testé
- [ ] Helm installé (si utilisation de Helm)
- [ ] Stockage local préparé sur les workers
- [ ] Secrets modifiés avec les vraies valeurs
- [ ] Scripts rendus exécutables
- [ ] Test du script en environnement de devops

## 📚 Références

- [Bash Scripting Guide](https://www.gnu.org/software/bash/manual/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

