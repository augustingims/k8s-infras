# Secrets Kubernetes

## ⚠️ IMPORTANT - Sécurité

**NE JAMAIS** commiter les secrets en clair dans Git !

Les fichiers dans ce dossier contiennent des valeurs par défaut pour le développement. En production, vous devez :

1. **Utiliser des valeurs sécurisées** : Générez des mots de passe forts
2. **Encoder en base64** : Les secrets Kubernetes doivent être encodés
3. **Utiliser Sealed Secrets** : Pour versionner les secrets de manière sécurisée
4. **Utiliser un gestionnaire de secrets** : Vault, AWS Secrets Manager, etc.

## Génération de secrets sécurisés

### Méthode 1 : Ligne de commande

```bash
# Générer un mot de passe aléatoire
openssl rand -base64 32

# Encoder en base64
echo -n 'mon-mot-de-passe' | base64

# Créer un secret directement avec kubectl
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=$(openssl rand -base64 32) \
  --namespace=devops \
  --dry-run=client -o yaml > postgres-secret.yaml
```

### Méthode 2 : Sealed Secrets (Recommandé pour production)

```bash
# Installer Sealed Secrets Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Installer kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar xfz kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Créer un SealedSecret
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD=$(openssl rand -base64 32) \
  --namespace=devops \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > postgres-sealed-secret.yaml

# Appliquer le SealedSecret
kubectl apply -f postgres-sealed-secret.yaml
```

### Méthode 3 : HashiCorp Vault

```bash
# Installer Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault --namespace vault --create-namespace

# Configurer Vault pour Kubernetes
# Voir: https://www.vaultproject.io/docs/platform/k8s
```

## Liste des secrets

### postgres-secrets.yaml
- `POSTGRES_USER` : Utilisateur PostgreSQL
- `POSTGRES_PASSWORD` : Mot de passe PostgreSQL
- `POSTGRES_DB` : Base de données par défaut
- `POSTGRES_MULTIPLE_DATABASES` : Bases de données multiples (séparées par virgule)

### pgadmin-secrets.yaml
- `PGADMIN_DEFAULT_EMAIL` : Email de connexion PgAdmin
- `PGADMIN_DEFAULT_PASSWORD` : Mot de passe PgAdmin

### sonarqube-secrets.yaml
- `SONAR_JDBC_USERNAME` : Utilisateur DB SonarQube
- `SONAR_JDBC_PASSWORD` : Mot de passe DB SonarQube
- `SONAR_JDBC_URL` : URL de connexion PostgreSQL
- `SONAR_ADMIN_USERNAME` : Admin SonarQube
- `SONAR_ADMIN_PASSWORD` : Mot de passe admin SonarQube

## Utilisation dans les pods

### Exemple 1 : Variables d'environnement

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: my-container
    image: my-image
    env:
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: postgres-secret
          key: POSTGRES_PASSWORD
```

### Exemple 2 : Monter comme fichier

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: my-container
    image: my-image
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: postgres-secret
```

### Exemple 3 : ImagePullSecrets

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  imagePullSecrets:
  - name: registry-credentials
  containers:
  - name: my-container
    image: registry.local/production/my-app:1.0.0
```

## Rotation des secrets

### Script de rotation automatique

```bash
#!/bin/bash
# rotate-secrets.sh

NAMESPACE="devops"
SECRET_NAME="postgres-secret"

# Générer un nouveau mot de passe
NEW_PASSWORD=$(openssl rand -base64 32)

# Mettre à jour le secret
kubectl create secret generic $SECRET_NAME \
  --from-literal=POSTGRES_PASSWORD=$NEW_PASSWORD \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Redémarrer les pods qui utilisent ce secret
kubectl rollout restart statefulset/postgres -n $NAMESPACE

echo "Secret rotated successfully!"
```

## Audit et monitoring

### Vérifier les secrets

```bash
# Lister tous les secrets
kubectl get secrets -n devops

# Voir les détails d'un secret (sans afficher les valeurs)
kubectl describe secret postgres-secret -n devops

# Décoder un secret (ATTENTION: sensible!)
kubectl get secret postgres-secret -n devops -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

### Logs d'accès aux secrets

Activez l'audit Kubernetes pour tracer l'accès aux secrets :

```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
```

## Best Practices

1. ✅ **Utilisez des mots de passe forts** (minimum 32 caractères)
2. ✅ **Rotez les secrets régulièrement** (tous les 90 jours)
3. ✅ **Limitez l'accès avec RBAC** (principe du moindre privilège)
4. ✅ **Utilisez Sealed Secrets ou Vault** pour versionner les secrets
5. ✅ **Activez l'encryption at rest** dans etcd
6. ✅ **Auditez l'accès aux secrets** avec Kubernetes audit logs
7. ❌ **Ne commitez JAMAIS** les secrets en clair dans Git
8. ❌ **N'affichez JAMAIS** les secrets dans les logs
9. ❌ **Ne partagez JAMAIS** les secrets par email ou chat

## Encryption at rest

Pour activer l'encryption des secrets dans etcd :

```yaml
# encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: <BASE64_ENCODED_SECRET>
    - identity: {}
```

Puis redémarrer l'API server avec :
```
--encryption-provider-config=/path/to/encryption-config.yaml
```

## Références

- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [HashiCorp Vault](https://www.vaultproject.io/docs/platform/k8s)
- [External Secrets Operator](https://external-secrets.io/)

