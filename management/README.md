# 🔧 Outils de Gestion du Cluster Kubernetes

Ce dossier contient les configurations pour les outils de gestion et d'administration du cluster Kubernetes.

## 📋 Table des Matières

- [Kubernetes Dashboard](#kubernetes-dashboard)
- [k9s - Terminal UI](#k9s---terminal-ui)
- [Lens - IDE Kubernetes](#lens---ide-kubernetes)
- [kubectl Plugins](#kubectl-plugins)
- [Autres Outils](#autres-outils)

## 🎛️ Kubernetes Dashboard

Interface web officielle pour gérer le cluster Kubernetes.

### Installation

```bash
# Via Helm (recommandé)
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update

helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --namespace kubernetes-dashboard \
  --create-namespace \
  --set service.type=ClusterIP \
  --set protocolHttp=false

# Appliquer les configurations RBAC
kubectl apply -f kubernetes-dashboard.yaml
```

### Accès au Dashboard

1. **Obtenir le token d'accès** :
```bash
kubectl -n kubernetes-dashboard create token admin-user
```

2. **Accéder via Ingress** :
```
https://dashboard.local
```

3. **Ou via port-forward** :
```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8443:443
# Accéder à https://localhost:8443
```

### Fonctionnalités

- ✅ Vue d'ensemble du cluster
- ✅ Gestion des workloads (Deployments, Pods, etc.)
- ✅ Gestion des services et Ingress
- ✅ Gestion du stockage (PV, PVC)
- ✅ Gestion des ConfigMaps et Secrets
- ✅ Logs et shell dans les pods
- ✅ Métriques de ressources

## 🖥️ k9s - Terminal UI

Interface en ligne de commande interactive pour Kubernetes.

### Installation

**macOS** :
```bash
brew install k9s
```

**Linux** :
```bash
# Via snap
sudo snap install k9s

# Ou télécharger le binaire
wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/
```

**Windows** :
```powershell
choco install k9s
```

### Utilisation

```bash
# Lancer k9s
k9s

# Lancer k9s dans un namespace spécifique
k9s -n devops

# Lancer k9s en mode read-only
k9s --readonly
```

### Raccourcis Clavier Essentiels

| Raccourci | Action |
|-----------|--------|
| `:pods` | Afficher les pods |
| `:svc` | Afficher les services |
| `:deploy` | Afficher les deployments |
| `:ns` | Changer de namespace |
| `d` | Décrire la ressource |
| `l` | Voir les logs |
| `s` | Shell dans le pod |
| `ctrl-d` | Supprimer |
| `?` | Aide |

### Configuration k9s

Créer `~/.k9s/config.yml` :

```yaml
k9s:
  refreshRate: 2
  maxConnRetry: 5
  readOnly: false
  noExitOnCtrlC: false
  ui:
    enableMouse: true
    headless: false
    logoless: false
    crumbsless: false
    skin: "dracula"
  skipLatestRevCheck: false
  disablePodCounting: false
  shellPod:
    image: busybox:1.35.0
    command: []
    args: []
    namespace: default
    limits:
      cpu: 100m
      memory: 100Mi
  imageScans:
    enable: false
  logger:
    tail: 100
    buffer: 5000
    sinceSeconds: 60
    fullScreenLogs: false
    textWrap: false
    showTime: false
  thresholds:
    cpu:
      critical: 90
      warn: 70
    memory:
      critical: 90
      warn: 70
```

## 🔍 Lens - IDE Kubernetes

Application desktop pour gérer les clusters Kubernetes.

### Installation

Télécharger depuis : https://k8slens.dev/

**macOS** :
```bash
brew install --cask lens
```

**Linux** :
```bash
# Télécharger le .deb ou .AppImage depuis le site officiel
```

**Windows** :
Télécharger l'installeur depuis le site officiel.

### Fonctionnalités

- ✅ Multi-cluster management
- ✅ Interface graphique intuitive
- ✅ Terminal intégré
- ✅ Métriques en temps réel
- ✅ Logs streaming
- ✅ Helm charts management
- ✅ Extensions et plugins

### Configuration

1. Ajouter le cluster :
   - Lens détecte automatiquement les clusters dans `~/.kube/config`
   - Ou ajouter manuellement via "Add Cluster"

2. Installer les extensions recommandées :
   - Lens Metrics (Prometheus)
   - Lens Resource Map
   - Lens Pod Security

## 🔌 kubectl Plugins

### krew - Plugin Manager

Installation :
```bash
# macOS/Linux
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# Ajouter au PATH
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
```

### Plugins Recommandés

```bash
# ctx - Changer de contexte rapidement
kubectl krew install ctx
kubectl ctx  # Lister les contextes
kubectl ctx <context-name>  # Changer de contexte

# ns - Changer de namespace rapidement
kubectl krew install ns
kubectl ns  # Lister les namespaces
kubectl ns devops  # Changer vers namespace devops

# tree - Afficher les ressources en arbre
kubectl krew install tree
kubectl tree deployment jenkins -n devops

# neat - Nettoyer l'output YAML
kubectl krew install neat
kubectl get pod jenkins-xxx -o yaml | kubectl neat

# tail - Tail logs de plusieurs pods
kubectl krew install tail
kubectl tail -n devops -l app=jenkins

# view-secret - Décoder les secrets
kubectl krew install view-secret
kubectl view-secret postgres-secrets -n devops

# resource-capacity - Voir la capacité des ressources
kubectl krew install resource-capacity
kubectl resource-capacity

# outdated - Vérifier les images outdated
kubectl krew install outdated
kubectl outdated
```

## 🛠️ Autres Outils

### kubectx et kubens

Changement rapide de contexte et namespace.

```bash
# Installation
brew install kubectx

# Utilisation
kubectx  # Lister les contextes
kubectx <context>  # Changer de contexte
kubens  # Lister les namespaces
kubens devops  # Changer vers namespace devops
```

### stern - Multi-pod logs

Afficher les logs de plusieurs pods simultanément.

```bash
# Installation
brew install stern

# Utilisation
stern jenkins -n devops  # Logs de tous les pods jenkins
stern -n devops -l app=jenkins  # Logs par label
stern --all-namespaces -l app=jenkins  # Tous les namespaces
```

### kubetail

Alternative à stern pour les logs.

```bash
# Installation
brew tap johanhaleby/kubetail && brew install kubetail

# Utilisation
kubetail jenkins -n devops
kubetail -l app=jenkins -n devops
```

### dive - Analyser les images Docker

Analyser les layers d'une image Docker.

```bash
# Installation
brew install dive

# Utilisation
dive <image-name>
```

### popeye - Cluster Sanitizer

Scanner le cluster pour détecter les problèmes.

```bash
# Installation
brew install derailed/popeye/popeye

# Utilisation
popeye  # Scanner tout le cluster
popeye -n devops  # Scanner un namespace
popeye --save  # Sauvegarder le rapport
```

## 📊 Commandes Utiles

### Monitoring Rapide

```bash
# Top nodes
kubectl top nodes

# Top pods
kubectl top pods -n devops
kubectl top pods --all-namespaces

# Événements récents
kubectl get events -n devops --sort-by='.lastTimestamp'

# Pods en erreur
kubectl get pods --all-namespaces --field-selector=status.phase!=Running
```

### Debugging

```bash
# Décrire un pod
kubectl describe pod <pod-name> -n <namespace>

# Logs
kubectl logs <pod-name> -n <namespace> -f
kubectl logs <pod-name> -n <namespace> --previous  # Logs du container précédent

# Shell dans un pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Port-forward
kubectl port-forward -n devops svc/jenkins 8080:8080
```

### Gestion des Ressources

```bash
# Lister toutes les ressources
kubectl get all -n devops

# Redémarrer un deployment
kubectl rollout restart deployment jenkins -n devops

# Scaler un deployment
kubectl scale deployment jenkins -n devops --replicas=2

# Voir l'historique des rollouts
kubectl rollout history deployment jenkins -n devops

# Rollback
kubectl rollout undo deployment jenkins -n devops
```

## 🎯 Best Practices

1. **Utiliser k9s pour l'administration quotidienne** - Plus rapide que kubectl
2. **Lens pour la vue d'ensemble** - Idéal pour comprendre l'état du cluster
3. **kubectl pour l'automatisation** - Scripts et CI/CD
4. **Installer les plugins kubectl** - Améliore la productivité
5. **Utiliser stern/kubetail pour les logs** - Meilleur que kubectl logs

## 🔐 Sécurité

- ⚠️ Le Dashboard admin a des privilèges cluster-admin
- ⚠️ Protéger l'accès au Dashboard avec un mot de passe fort
- ⚠️ Utiliser RBAC pour limiter les accès
- ⚠️ Activer l'audit logging
- ⚠️ Restreindre l'accès réseau au Dashboard

## 📚 Ressources

- [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [k9s Documentation](https://k9scli.io/)
- [Lens Documentation](https://docs.k8slens.dev/)
- [kubectl Plugins](https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/)
- [krew](https://krew.sigs.k8s.io/)

