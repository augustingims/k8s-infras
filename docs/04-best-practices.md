# Best Practices Kubernetes

## 🎯 Vue d'ensemble

Ce document présente les meilleures pratiques pour gérer et maintenir l'infrastructure Kubernetes.

## 🔐 Sécurité

### 1. Gestion des Secrets

**❌ À éviter** :
```yaml
env:
- name: DB_PASSWORD
  value: "password123"  # Jamais en clair !
```

**✅ Recommandé** :
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: password
```

**Best Practices** :
- Utiliser Sealed Secrets ou Vault pour la production
- Chiffrer les secrets au repos (encryption at rest)
- Rotation régulière des secrets
- Ne jamais commiter les secrets dans Git

```bash
# Utiliser Sealed Secrets
kubectl create secret generic mysecret --dry-run=client -o yaml | \
  kubeseal -o yaml > mysealedsecret.yaml
```

### 2. RBAC (Role-Based Access Control)

**Principe du moindre privilège** :
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]  # Seulement lecture
```

**Best Practices** :
- Créer des ServiceAccounts dédiés pour chaque application
- Éviter d'utiliser le ServiceAccount par défaut
- Limiter les permissions au strict nécessaire
- Auditer régulièrement les permissions

### 3. Network Policies

**Isoler les namespaces** :
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: devops
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  # Deny all by default
```

**Autoriser uniquement le trafic nécessaire** :
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### 4. Pod Security Standards

**Utiliser des SecurityContexts** :
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
```

## 📊 Ressources et Performance

### 1. Définir les Requests et Limits

**❌ À éviter** :
```yaml
# Pas de limits = risque d'OOM
resources: {}
```

**✅ Recommandé** :
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

**Best Practices** :
- Toujours définir requests et limits
- Requests = ressources garanties
- Limits = maximum autorisé
- Monitorer et ajuster selon l'usage réel

### 2. Quality of Service (QoS)

**Guaranteed** (meilleure priorité) :
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "1Gi"  # Égal à requests
    cpu: "500m"    # Égal à requests
```

**Burstable** (priorité moyenne) :
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"  # Supérieur à requests
    cpu: "500m"
```

### 3. Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## 🏗️ Architecture et Design

### 1. Labels et Annotations

**Labels standardisés** :
```yaml
metadata:
  labels:
    app: user-app
    component: backend
    environment: production
    version: v1.2.3
    managed-by: helm
```

**Annotations pour métadonnées** :
```yaml
metadata:
  annotations:
    description: "User management service"
    contact: "team-backend@devops"
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
```

### 2. Health Checks

**Liveness Probe** (redémarre si échoue) :
```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 120
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
```

**Readiness Probe** (retire du service si échoue) :
```yaml
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Startup Probe** (pour applications lentes à démarrer) :
```yaml
startupProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 10
  failureThreshold: 30  # 300s max
```

### 3. Rolling Updates

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # 1 pod supplémentaire pendant l'update
    maxUnavailable: 0  # Aucun pod indisponible
```

### 4. Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: user-app
```

## 💾 Stockage

### 1. Utiliser des PersistentVolumeClaims

**❌ À éviter** :
```yaml
volumes:
- name: data
  hostPath:
    path: /data  # Couplage fort avec le nœud
```

**✅ Recommandé** :
```yaml
volumes:
- name: data
  persistentVolumeClaim:
    claimName: app-pvc
```

### 2. StorageClass appropriée

- **local-storage** : Performance, mais pas de réplication
- **NFS** : Partagé, mais performance moyenne
- **Ceph/Rook** : Distribué, répliqué, performant

## 🔄 CI/CD

### 1. GitOps

**Utiliser ArgoCD ou Flux** :
- Infrastructure as Code
- Déploiements déclaratifs
- Rollback facile
- Audit trail

### 2. Image Tags

**❌ À éviter** :
```yaml
image: myapp:latest  # Non déterministe
```

**✅ Recommandé** :
```yaml
image: myapp:v1.2.3  # Version spécifique
# ou
image: myapp:sha256-abc123  # Digest
```

### 3. Image Pull Policy

```yaml
imagePullPolicy: Always  # Pour :latest
imagePullPolicy: IfNotPresent  # Pour versions spécifiques
```

## 🌐 Networking

### 1. Services

**ClusterIP** (par défaut) :
```yaml
type: ClusterIP  # Interne uniquement
```

**NodePort** (pour tests) :
```yaml
type: NodePort
ports:
- port: 80
  nodePort: 30080  # 30000-32767
```

**LoadBalancer** (cloud) :
```yaml
type: LoadBalancer  # Crée un LB externe
```

### 2. Ingress

**Utiliser un seul Ingress par namespace** :
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-ingress
spec:
  rules:
  - host: app1.example.com
    # ...
  - host: app2.example.com
    # ...
```

## 🔧 Maintenance

### 1. Namespaces

**Organiser par environnement** :
- `devops` : Infrastructure CI/CD
- `monitoring` : Prometheus, Grafana

### 2. ResourceQuotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: devops-quota
  namespace: devops
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "10"
```

### 3. LimitRanges

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
spec:
  limits:
  - default:
      memory: 512Mi
      cpu: 500m
    defaultRequest:
      memory: 256Mi
      cpu: 250m
    type: Container
```

## 📝 Documentation

### 1. Documenter les manifests

```yaml
metadata:
  annotations:
    description: "User management microservice"
    owner: "backend-team"
    runbook: "https://wiki.devops.local/runbooks/app"
```

### 2. README par composant

Chaque dossier devrait avoir un README.md expliquant :
- Objectif du composant
- Dépendances
- Configuration
- Procédure de déploiement

## 🚀 Checklist de déploiement

- [ ] Secrets créés et sécurisés
- [ ] Resources requests/limits définis
- [ ] Health checks configurés
- [ ] Labels et annotations standardisés
- [ ] RBAC configuré (principe du moindre privilège)
- [ ] Network Policies en place
- [ ] Monitoring activé
- [ ] Backups configurés
- [ ] Documentation à jour
- [ ] Tests effectués en staging
- [ ] Plan de rollback préparé

## 📚 Références

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [12 Factor App](https://12factor.net/)
- [CNCF Cloud Native Trail Map](https://github.com/cncf/trailmap)

