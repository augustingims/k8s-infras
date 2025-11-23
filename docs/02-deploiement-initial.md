# Déploiement Initial de l'Infrastructure

## 📋 Vue d'ensemble

Ce guide vous accompagne dans le déploiement initial de l'infrastructure DevOps sur Kubernetes.

## ✅ Prérequis

- Cluster Kubernetes opérationnel (voir [01-installation-cluster.md](01-installation-cluster.md))
- kubectl configuré et connecté au cluster
- Helm installé (optionnel mais recommandé)
- Accès aux fichiers de configuration dans le dossier `k8s-infras/`

## 🚀 Déploiement automatique

### Option 1 : Script automatisé (Recommandé)

```bash
cd k8s-new/scripts
chmod +x deploy-all.sh
./deploy-all.sh
```

Le script va :
1. Créer les namespaces
2. Configurer le stockage
3. Créer les secrets et ConfigMaps
4. Déployer l'infrastructure DevOps

### Option 2 : Déploiement manuel (étape par étape)

Suivez les sections ci-dessous pour un déploiement manuel.

## 📝 Déploiement manuel

### Étape 1 : Créer les namespaces

```bash
cd k8s-infras

# Créer tous les namespaces
kubectl apply -f namespaces/

# Vérifier
kubectl get namespaces
```

### Étape 2 : Configurer le stockage

```bash
# Créer la StorageClass
kubectl apply -f base/storage/storage-class.yaml

# Créer les PersistentVolumes
kubectl apply -f base/storage/pv-devops.yaml

# Vérifier
kubectl get pv
kubectl get storageclass
```

### Étape 3 : Créer les secrets

⚠️ **IMPORTANT** : Modifiez les secrets avec vos propres valeurs avant de les appliquer !

```bash
# Éditer les secrets
nano base/secrets/postgres-secrets.yaml
nano base/secrets/pgadmin-secrets.yaml
nano base/secrets/sonarqube-secrets.yaml

# Appliquer les secrets
kubectl apply -f base/secrets/

# Vérifier (ne pas afficher les valeurs)
kubectl get secrets -n devops
```

### Étape 4 : Créer les ConfigMaps

```bash
# Appliquer les ConfigMaps
kubectl apply -f base/configmaps/

# Vérifier
kubectl get configmaps -n devops
```

### Étape 5 : Déployer PostgreSQL

```bash
# PostgreSQL pour devops
kubectl apply -f infrastructure/postgres/statefulset-devops.yaml
kubectl apply -f infrastructure/postgres/pgadmin-devops.yaml

# Attendre que PostgreSQL soit prêt
kubectl wait --for=condition=ready pod -l app=postgres -n devops --timeout=300s
# Vérifier
kubectl get pods -n devops -l app=postgres
```

### Étape 6 : Déployer Jenkins

```bash
# Déployer Jenkins
kubectl apply -f infrastructure/jenkins/deployment.yaml

# Attendre que Jenkins soit prêt
kubectl wait --for=condition=ready pod -l app=jenkins -n devops --timeout=600s

# Récupérer le mot de passe initial
kubectl exec -n devops -it $(kubectl get pods -n devops -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword

# Vérifier
kubectl get pods -n devops -l app=jenkins
kubectl logs -n devops -l app=jenkins
```

### Étape 7 : Déployer Nexus

```bash
# Déployer Nexus
kubectl apply -f infrastructure/nexus/deployment.yaml

# Attendre (Nexus prend du temps à démarrer)
kubectl wait --for=condition=ready pod -l app=nexus -n devops --timeout=600s

# Récupérer le mot de passe admin
kubectl exec -n devops -it $(kubectl get pods -n devops -l app=nexus -o jsonpath='{.items[0].metadata.name}') -- cat /nexus-data/admin.password

# Vérifier
kubectl get pods -n devops -l app=nexus
```

### Étape 8 : Déployer SonarQube

```bash
# Déployer SonarQube
kubectl apply -f infrastructure/sonarqube/deployment.yaml

# Attendre
kubectl wait --for=condition=ready pod -l app=sonarqube -n devops --timeout=600s

# Vérifier
kubectl get pods -n devops -l app=sonarqube
kubectl logs -n devops -l app=sonarqube
```

## 🔍 Vérification du déploiement

### Vérifier tous les pods

```bash
# Namespace devops
kubectl get pods -n devops
# Tous les namespaces
kubectl get pods --all-namespaces
```

### Vérifier les services

```bash
kubectl get svc -n devops
```

### Vérifier les Ingress

```bash
kubectl get ingress -n devops
```

### Tester l'accès aux services

```bash
# Via port-forward (pour test)
kubectl port-forward -n devops svc/jenkins 8080:8080
# Ouvrir http://localhost:8080/jenkins

# Via NodePort (si pas de DNS)
# Récupérer l'IP d'un worker
kubectl get nodes -o wide
```

## 📊 Tableau de bord

### Accès aux services

| Service | URL                                                  | Credentials par défaut |
|---------|------------------------------------------------------|------------------------|
| Jenkins | http://jenkins.devops.svc.cluster.local:8080/jenkins | admin / (voir logs) |
| Nexus | http://nexus.devops.svc.cluster.local:8081           | admin / (voir /nexus-data/admin.password) |
| SonarQube | http://sonarqube.devops.svc.cluster.local:9000       | admin / admin |
| PgAdmin | http://pgadmn.devops.svc.cluster.local:80            | admin@devops.local / (voir secrets) |

## 🔐 Sécurisation post-déploiement

1. **Changer tous les mots de passe par défaut**
2. **Configurer l'authentification LDAP/OAuth** (si applicable)
3. **Activer l'audit logging**
4. **Configurer les Network Policies**
5. **Mettre en place les backups automatiques**
