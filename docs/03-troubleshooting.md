# Guide de Troubleshooting

## 🔍 Problèmes courants et solutions

### 1. Pods en état Pending

#### Symptôme
```bash
kubectl get pods -n devops
NAME                       READY   STATUS    RESTARTS   AGE
jenkins-xxx                0/1     Pending   0          5m
```

#### Causes possibles

**A. Ressources insuffisantes**
```bash
# Vérifier les ressources des nœuds
kubectl describe nodes

# Vérifier les événements
kubectl describe pod jenkins-xxx -n devops
```

**Solution** : Augmenter les ressources ou réduire les requests/limits

**B. PVC non lié**
```bash
# Vérifier les PVC
kubectl get pvc -n devops

# Vérifier les PV disponibles
kubectl get pv
```

**Solution** : Créer les PV manquants ou vérifier les labels/selectors

**C. Contraintes de placement non satisfaites**
```bash
# Vérifier les labels des nœuds
kubectl get nodes --show-labels
```

**Solution** : Labelliser les nœuds correctement

### 2. Pods en CrashLoopBackOff

#### Symptôme
```bash
NAME                       READY   STATUS             RESTARTS   AGE
sonarqube-xxx              0/1     CrashLoopBackOff   5          10m
```

#### Diagnostic
```bash
# Voir les logs
kubectl logs sonarqube-xxx -n devops

# Voir les logs du conteneur précédent
kubectl logs sonarqube-xxx -n devops --previous

# Décrire le pod
kubectl describe pod sonarqube-xxx -n devops
```

#### Solutions courantes

**A. SonarQube - vm.max_map_count trop bas**
```bash
# Sur chaque nœud
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**B. Problème de permissions**
```bash
# Vérifier les permissions du volume
kubectl exec -it sonarqube-xxx -n devops -- ls -la /opt/sonarqube/data

# Corriger si nécessaire (via initContainer dans le manifest)
```

**C. Secrets manquants ou incorrects**
```bash
# Vérifier les secrets
kubectl get secrets -n devops
kubectl describe secret postgres-secret -n devops

# Recréer le secret si nécessaire
kubectl delete secret postgres-secret -n devops
kubectl apply -f base/secrets/postgres-secrets.yaml
```

### 3. Services inaccessibles

#### Symptôme
Impossible d'accéder à un service via son URL

#### Diagnostic

**A. Vérifier le pod**
```bash
kubectl get pods -n devops -l app=jenkins
kubectl logs -n devops -l app=jenkins
```

**B. Vérifier le service**
```bash
kubectl get svc -n devops jenkins
kubectl describe svc jenkins -n devops

# Tester depuis un pod
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Dans le pod:
apk add curl
curl http://jenkins.devops.svc.cluster.local:8080
```

### 4. Problèmes de stockage

#### PVC reste en Pending

```bash
# Vérifier le PVC
kubectl describe pvc jenkins-pvc -n devops

# Vérifier les PV disponibles
kubectl get pv

# Vérifier les événements
kubectl get events -n devops --sort-by='.lastTimestamp'
```

**Solutions** :
- Créer un PV correspondant
- Vérifier la StorageClass
- Vérifier les labels et selectors

#### Erreur de montage de volume

```bash
# Vérifier les logs du kubelet sur le nœud
ssh <node>
sudo journalctl -u kubelet -f

# Vérifier les permissions
ls -la /mnt/k8s-storage/
```

**Solutions** :
```bash
# Créer le répertoire si manquant
sudo mkdir -p /mnt/k8s-storage/jenkins
sudo chmod 777 /mnt/k8s-storage/jenkins

# Vérifier le SELinux (si activé)
sudo setenforce 0
```

### 5. Problèmes réseau

#### Pods ne peuvent pas communiquer

```bash
# Tester la connectivité
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Dans le pod:
apk add curl
curl http://postgres.devops.svc.cluster.local:5432

# Vérifier le CNI
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl logs -n kube-system -l k8s-app=calico-node
```

#### DNS ne fonctionne pas

```bash
# Vérifier CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Tester la résolution DNS
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Dans le pod:
nslookup kubernetes.default
nslookup postgres.devops.svc.cluster.local
```

### 6. Problèmes de performance

#### Pods lents à démarrer

```bash
# Vérifier les ressources
kubectl top nodes
kubectl top pods -n devops

# Vérifier les événements
kubectl get events -n devops --sort-by='.lastTimestamp'

# Vérifier les limites de ressources
kubectl describe pod <pod-name> -n devops | grep -A 5 "Limits"
```

#### Base de données lente

```bash
# Vérifier les ressources PostgreSQL
kubectl top pod -n devops -l app=postgres

# Se connecter à PostgreSQL
kubectl exec -it postgres-0 -n devops -- psql -U postgres

# Dans PostgreSQL:
SELECT * FROM pg_stat_activity;
SELECT * FROM pg_stat_database;
```

## 🛠️ Commandes utiles

### Debugging général

```bash
# Voir tous les événements
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Voir les logs d'un pod
kubectl logs <pod-name> -n <namespace> -f

# Exécuter une commande dans un pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Port-forward pour tester
kubectl port-forward -n <namespace> <pod-name> 8080:8080

# Copier des fichiers
kubectl cp <namespace>/<pod-name>:/path/to/file ./local-file
```

### Nettoyage

```bash
# Supprimer les pods en erreur
kubectl delete pods --field-selector status.phase=Failed -n devops

# Forcer la suppression d'un pod
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0

# Nettoyer les images inutilisées
kubectl get nodes -o name | xargs -I {} kubectl debug {} -it --image=alpine -- sh -c "crictl rmi --prune"
```

### Monitoring

```bash
# Utilisation des ressources
kubectl top nodes
kubectl top pods -n devops
# Capacité du cluster
kubectl describe nodes | grep -A 5 "Allocated resources"
```

## 📞 Obtenir de l'aide

Si le problème persiste :

1. **Collecter les informations** :
```bash
# Créer un rapport de diagnostic
kubectl cluster-info dump > cluster-dump.txt
kubectl get all --all-namespaces > all-resources.txt
```

2. **Vérifier les logs système** :
```bash
# Sur chaque nœud
sudo journalctl -u kubelet -n 100
sudo journalctl -u containerd -n 100
```

3. **Consulter la documentation** :
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)

## 📚 Références

- [Kubernetes Debugging](https://kubernetes.io/docs/tasks/debug/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

