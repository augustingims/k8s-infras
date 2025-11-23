# Stockage Kubernetes - Guide Complet

## 📋 Vue d'ensemble

Ce dossier contient les définitions de stockage pour l'infrastructure Kubernetes :
- **StorageClass** : Définit les types de stockage disponibles
- **PersistentVolume (PV)** : Volumes de stockage physiques
- **PersistentVolumeClaim (PVC)** : Demandes de stockage par les applications

## 🏗️ Architecture de stockage

```
┌─────────────────────────────────────────────────────────┐
│                    StorageClass                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ local-storage│  │ nfs-storage  │  │  longhorn    │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│              PersistentVolumes (PV)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ pv-postgres  │  │  pv-jenkins  │  │  pv-nexus    │   │
│  │   2Gi        │  │    1Gi       │  │    1Gi       │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│         PersistentVolumeClaims (PVC)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │postgres-pvc  │  │ jenkins-pvc  │  │  nexus-pvc   │   │
│  │  (devops)    │  │  (devops)    │  │  (devops)    │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    Pods/StatefulSets                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  postgres    │  │   jenkins    │  │    nexus     │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 📊 Besoins en stockage

### Namespace: devops

| Service | Taille | Type | Description |
|---------|--------|------|-------------|
| PostgreSQL | 2 Gi   | RWO | Base de données |
| Jenkins | 1 Gi   | RWO | CI/CD data |
| Nexus | 1 Gi   | RWO | Artifacts repository |
| SonarQube | 2 Gi   | RWO | Code analysis data |

**Total: ~6 Gi**

## 🔧 Options de stockage

### Option 1 : Local Storage (Développement)

**Avantages** :
- ✅ Simple à configurer
- ✅ Pas de dépendances externes
- ✅ Performances élevées

**Inconvénients** :
- ❌ Pas de réplication
- ❌ Lié à un nœud spécifique
- ❌ Pas de migration automatique

**Configuration** :

```bash
# Créer les répertoires sur chaque worker
ssh worker1
sudo mkdir -p /mnt/k8s-storage/{postgres,jenkins,nexus,sonarqube,minio}
sudo chmod 777 /mnt/k8s-storage/*

ssh worker2
sudo mkdir -p /mnt/k8s-storage/{postgres,jenkins,nexus,sonarqube,minio}
sudo chmod 777 /mnt/k8s-storage/*
```

### Option 2 : NFS (Recommandé pour petites installations)

**Avantages** :
- ✅ Stockage partagé
- ✅ Facile à sauvegarder
- ✅ Accessible depuis tous les nœuds

**Inconvénients** :
- ❌ Point de défaillance unique
- ❌ Performances moyennes
- ❌ Nécessite un serveur NFS

**Installation du serveur NFS** :

```bash
# Sur le serveur NFS (peut être le master)
sudo apt-get update
sudo apt-get install -y nfs-kernel-server

# Créer le répertoire d'export
sudo mkdir -p /export/k8s-storage
sudo chmod 777 /export/k8s-storage

# Configurer les exports
sudo tee /etc/exports <<EOF
/export/k8s-storage *(rw,sync,no_subtree_check,no_root_squash)
EOF

# Redémarrer NFS
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
```

**Installation du client NFS sur les workers** :

```bash
# Sur chaque worker
sudo apt-get install -y nfs-common
```

**Installer le provisioner NFS** :

```bash
# Installer nfs-subdir-external-provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=<NFS_SERVER_IP> \
  --set nfs.path=/export/k8s-storage \
  --set storageClass.name=nfs-storage \
  --namespace kube-system
```

### Option 3 : Longhorn (Recommandé pour production)

**Avantages** :
- ✅ Réplication automatique
- ✅ Snapshots et backups
- ✅ Interface web de gestion
- ✅ Haute disponibilité

**Inconvénients** :
- ❌ Plus complexe
- ❌ Nécessite plus de ressources

**Installation** :

```bash
# Installer les dépendances sur chaque nœud
sudo apt-get install -y open-iscsi nfs-common

# Installer Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml

# Vérifier l'installation
kubectl get pods -n longhorn-system

# Accéder à l'interface web
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Ouvrir http://localhost:8080
```

### Option 4 : Ceph/Rook (Pour grandes installations)

**Avantages** :
- ✅ Très scalable
- ✅ Haute performance
- ✅ Support RWX (ReadWriteMany)

**Inconvénients** :
- ❌ Complexe à configurer
- ❌ Nécessite au moins 3 nœuds
- ❌ Consomme beaucoup de ressources

## 📝 Création manuelle des PV (Local Storage)

### Sur Worker 1

```bash
# Créer les répertoires
sudo mkdir -p /mnt/k8s-storage/postgres-devops
sudo mkdir -p /mnt/k8s-storage/jenkins
sudo mkdir -p /mnt/k8s-storage/nexus
sudo chmod -R 777 /mnt/k8s-storage/

# Labelliser le nœud
kubectl label nodes worker1 storage=local
```

### Sur Worker 2

```bash
# Créer les répertoires
sudo mkdir -p /mnt/k8s-storage/sonarqube
sudo chmod -R 777 /mnt/k8s-storage/

# Labelliser le nœud
kubectl label nodes worker2 storage=local
```

## 🚀 Déploiement

### 1. Créer la StorageClass

```bash
kubectl apply -f storage-class.yaml
```

### 2. Créer les PersistentVolumes

```bash
# Pour le namespace devops
kubectl apply -f pv-devops.yaml
```

### 3. Vérifier les PV

```bash
kubectl get pv
kubectl describe pv pv-postgres-devops
```

## 🔍 Monitoring du stockage

### Vérifier l'utilisation

```bash
# Lister tous les PV et PVC
kubectl get pv,pvc --all-namespaces

# Voir l'utilisation détaillée
kubectl describe pv <pv-name>
kubectl describe pvc <pvc-name> -n <namespace>

# Vérifier l'espace disque sur les nœuds
kubectl get nodes -o custom-columns=NAME:.metadata.name,STORAGE:.status.allocatable.ephemeral-storage
```

### Alertes de stockage

Configurez des alertes Prometheus pour surveiller :
- Utilisation du stockage > 80%
- PVC en état Pending
- Erreurs de montage de volumes

## 💾 Backup et Restore

### Backup avec Velero

```bash
# Installer Velero
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket velero-backups \
  --secret-file ./credentials-velero

# Backup d'un namespace
velero backup create devops-backup --include-namespaces devops

# Backup de PVC spécifiques
velero backup create postgres-backup --include-resources pvc,pv --selector app=postgres
```

### Backup manuel

```bash
# Script de backup PostgreSQL
kubectl exec -n devops postgres-0 -- pg_dumpall -U postgres > backup-$(date +%Y%m%d).sql

# Copier les données d'un PVC
kubectl cp devops/postgres-0:/var/lib/postgresql/data ./backup-postgres/
```

## 🔧 Troubleshooting

### PVC reste en Pending

```bash
# Vérifier les événements
kubectl describe pvc <pvc-name> -n <namespace>

# Vérifier les PV disponibles
kubectl get pv

# Vérifier les labels et selectors
kubectl get pv --show-labels
```

### Erreur de montage

```bash
# Vérifier les logs du kubelet
journalctl -u kubelet -f

# Vérifier les permissions
ls -la /mnt/k8s-storage/

# Vérifier le montage
mount | grep k8s-storage
```

### Espace disque plein

```bash
# Nettoyer les images Docker inutilisées
docker system prune -a

# Augmenter la taille du PV (si supporté)
kubectl patch pv <pv-name> -p '{"spec":{"capacity":{"storage":"5Gi"}}}'

# Redimensionner le PVC
kubectl patch pvc <pvc-name> -n <namespace> -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
```

## 📚 Références

- [Kubernetes Storage](https://kubernetes.io/docs/concepts/storage/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [NFS Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- [Velero Backup](https://velero.io/docs/)

