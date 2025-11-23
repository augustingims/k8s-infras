# Infrastructure Kubernetes - k8s-infras

Mise en place d'un cluster kubernetes

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Structure du projet](#structure-du-projet)
- [Déploiement rapide](#déploiement-rapide)
- [Documentation détaillée](#documentation-détaillée)
- [Services déployés](#services-déployés)
- [Sécurité](#sécurité)
- [Monitoring et Logs](#monitoring-et-logs)
- [Troubleshooting](#troubleshooting)

## 🎯 Vue d'ensemble

Cette infrastructure Kubernetes est conçue pour un cluster Kubernetes avec **1 master et 2 workers**.

### Concepts clés

| Aspect | Kubernetes |
|--------|------------|
| Orchestration | Deployments/StatefulSets |
| Réseau | CNI (Calico/Flannel) |
| Load Balancing | Services + Ingress |
| Secrets | Kubernetes Secrets |
| Volumes | PersistentVolumes/PVC |
| Reverse Proxy | Ingress Controller + Cert-Manager |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Master     │  │   Worker 1   │  │   Worker 2   │       │
│  │              │  │              │  │              │       │
│  │ - API Server │  │ - Kubelet    │  │ - Kubelet    │       │
│  │ - Scheduler  │  │ - Pods       │  │ - Pods       │       │
│  │ - Controller │  │              │  │              │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘

┌───────────────────────┐
│    Namespaces         │
│  ┌──────────────┐     │
│  │   devops     │     │
│  │              │     │
│  │ - Jenkins    │     │
│  │ - Nexus      │     │
│  │ - SonarQube  │     │
│  │ - PostgreSQL │     │
│  │ - MinIO      │     │
│  │ - Portainer  │     │
│  └──────────────┘     │
└───────────────────────┘

```

## ✅ Prérequis

### Cluster Kubernetes

- **Kubernetes**: v1.28+ (recommandé v1.30)
- **Topologie**: 1 Master + 2 Workers
- **CNI**: Calico, Flannel, ou Weave Net
- **Runtime**: containerd ou CRI-O

### Outils requis

```bash
# kubectl
kubectl version --client

# helm (optionnel mais recommandé)
helm version

# kustomize (intégré dans kubectl)
kubectl kustomize --help
```

### Ressources minimales

| Node | CPU | RAM | Stockage |
|------|-----|-----|----------|
| Master | 2 cores | 4 GB | 50 GB |
| Worker 1 | 4 cores | 8 GB | 100 GB |
| Worker 2 | 4 cores | 8 GB | 100 GB |

### Stockage

- **StorageClass** configurée (local-path, NFS, Ceph, etc.)
- **PersistentVolumes** disponibles ou provisionnement dynamique

## 📁 Structure du projet

```
k8s-new/
├── README.md                          # Ce fichier
├── namespaces/                        # Définition des namespaces
│   ├── devops-namespace.yaml
│   
├── base/                              # Ressources de base
│   ├── storage/                       # PV, PVC, StorageClass
│   │   ├── storage-class.yaml
│   │   └── pv-devops.yaml
│   ├── secrets/                       # Secrets Kubernetes
│   │   ├── postgres-secrets.yaml
│   │   ├── pgadmin-secrets.yaml
│   │   └── sonarqube-secrets.yaml
│   └── configmaps/                    # ConfigMaps
│       ├── postgres-init.yaml
├── infrastructure/                    # Services d'infrastructure
│   ├── postgres/
│   │   ├── statefulset-devops.yaml
│   │   └── pgadmin-devops.yaml
│   ├── jenkins/
│   │   ├── deployment.yaml
│   │   └── jenkins-agent.yaml
│   ├── nexus/
│   │   ├── deployment.yaml
│   └── sonarqube/
│       ├── deployment.yaml
├── scripts/                           # Scripts d'automatisation
│   ├── deploy-all.sh
│   ├── deploy-infrastructure.sh
│   ├── cleanup.sh
│   ├── backup.sh
│   └── restore.sh
└── docs/                              # Documentation détaillée
    ├── 01-installation-cluster.md         # ✅ Installation Kubernetes (kubeadm, CNI)
    ├── 02-deploiement-initial.md          # ✅ Déploiement pas à pas
    ├── 08-troubleshooting.md              # ✅ Résolution de problèmes
    └── 09-best-practices.md               # ✅ Best practices Kubernetes
```

## 📚 Documentation

### Guides principaux

- **[01-installation-cluster.md](docs/01-installation-cluster.md)** : Installation complète d'un cluster Kubernetes (kubeadm, containerd, Calico)
- **[02-deploiement-initial.md](docs/02-deploiement-initial.md)** : Déploiement de l'infrastructure (manuel et automatisé)
- **[08-troubleshooting.md](docs/03-troubleshooting)** : Résolution des problèmes courants (pods, réseau, stockage, ingress)
- **[09-best-practices.md](docs/04-best-practices)** : Best practices Kubernetes (sécurité, ressources, monitoring)

### Documentation par composant

- **[scripts/README.md](scripts/README.md)** : Utilisation des scripts d'automatisation
- **[base/secrets/README.md](base/secrets/README.md)** : Gestion des secrets (Sealed Secrets, Vault)
- **[base/storage/README.md](base/storage/README.md)** : Configuration du stockage (local, NFS, Ceph)
- **[infrastructure/jenkins/README.md](infrastructure/jenkins/README.md)** : Configuration Jenkins avec agents Kubernetes
```

## 🚀 Déploiement rapide

### 1. Préparation

```bash
# Cloner le repository
cd /path/to/devops-k8s
git clone https://github.com/your-repo/k8s-infras.git
cd k8s-infras

# Vérifier la connexion au cluster
kubectl cluster-info
kubectl get nodes
```

### 2. Créer les namespaces

```bash
kubectl apply -f namespaces/
```

### 3. Déployer le stockage

```bash
kubectl apply -f base/storage/
```

### 4. Créer les secrets

```bash
# Éditer les secrets avec vos valeurs
kubectl apply -f base/secrets/
```

### 5. Déployer l'infrastructure

```bash
# Option 1: Déploiement manuel
kubectl apply -f infrastructure/postgres/
kubectl apply -f infrastructure/jenkins/
kubectl apply -f infrastructure/nexus/
kubectl apply -f infrastructure/sonarqube/

# Option 2: Script automatisé
./scripts/deploy-infrastructure.sh
```

## 📚 Documentation détaillée

Consultez le dossier `docs/` pour des guides détaillés :

1. **[Installation du cluster](docs/01-installation-cluster.md)** - Configuration initiale du cluster Kubernetes
2. **[Déploiement initial](docs/02-deploiement-initial.md)** - Déploiement pas à pas de l'infrastructure
3. **[Troubleshooting](docs/03-troubleshooting)** - Résolution des problèmes courants
4. **[Best Practices](docs/04-best-practices)** - Bonnes pratiques Kubernetes

## 🔧 Services déployés

### Namespace: devops

| Service | Type | Port | Description |
|---------|------|------|-------------|
| Jenkins | ClusterIP | 8080 | CI/CD Server |
| Nexus | ClusterIP | 8081 | Artifact Repository |
| SonarQube | ClusterIP | 9000 | Code Quality |
| PostgreSQL | ClusterIP | 5432 | Database |
| PgAdmin | ClusterIP | 80 | DB Management |

## 🔒 Sécurité

### Secrets Management

- Tous les secrets sont stockés dans Kubernetes Secrets
- Utilisation de `sealed-secrets` recommandée pour la production
- Rotation régulière des secrets

### Network Policies

- Isolation des namespaces
- Restriction des communications inter-pods
- Whitelist des IPs autorisées

### RBAC

- Rôles et permissions définis par namespace
- ServiceAccounts dédiés pour chaque service
- Principe du moindre privilège

## 📊 Monitoring et Logs

### Prometheus & Grafana (Recommandé)

```bash
# Installation via Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### Logs centralisés

- **EFK Stack**: Elasticsearch + Fluentd + Kibana
- **Loki**: Alternative légère avec Grafana

## 🆘 Troubleshooting

### Vérifier l'état des pods

```bash
kubectl get pods -n devops
kubectl describe pod <pod-name> -n devops
kubectl logs <pod-name> -n devops
```

### Vérifier les services

```bash
kubectl get svc -n devops
kubectl get ingress -n devops
```

### Problèmes courants

Consultez [docs/04-troubleshooting.md](docs/03-troubleshooting) pour les solutions détaillées.

## 📞 Support

Pour toute question ou problème :

- **Documentation**: Voir le dossier `docs/`
- **Issues**: Créer une issue dans le repository

---

**Note**: Cette infrastructure est conçue pour être évolutive. Vous pouvez facilement ajouter des workers ou des services supplémentaires.

