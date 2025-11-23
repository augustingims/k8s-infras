# Jenkins sur Kubernetes

## 📋 Vue d'ensemble

Jenkins est déployé dans le namespace `devops` avec les caractéristiques suivantes :
- **Image**: jenkins/jenkins:2.464-jdk17
- **Stockage**: 1Gi PersistentVolume
- **Ressources**: 2Gi RAM (request) / 4Gi RAM (limit)
- **Accès Docker**: Via socket Docker monté

## 🚀 Déploiement

### 1. Créer le namespace (si pas déjà fait)

```bash
kubectl apply -f ../../namespaces/devops-namespace.yaml
```

### 2. Créer les secrets nécessaires

```bash
kubectl apply -f ../../base/secrets/registry-secrets.yaml
```

### 3. Déployer Jenkins

```bash
kubectl apply -f deployment.yaml
```

### 4. Vérifier le déploiement

```bash
# Vérifier le pod
kubectl get pods -n devops -l app=jenkins

# Vérifier les logs
kubectl logs -n devops -l app=jenkins -f

# Vérifier le service
kubectl get svc -n devops jenkins
```

### 5. Récupérer le mot de passe initial

```bash
kubectl exec -n devops -it $(kubectl get pods -n devops -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword
```

## 🔧 Configuration initiale

### Accéder à Jenkins

Option 1: Via Port-Forward (pour test)
```bash
kubectl port-forward -n devops svc/jenkins 8080:8080
# Ouvrir http://localhost:8080/jenkins
```

Option 2: Via Ingress (recommandé)
```bash
# Appliquer l'ingress (voir ../../ingress/ingress-rules.yaml)
kubectl apply -f ../../ingress/ingress-rules.yaml
# Accéder via https://jenkins.local
```

### Plugins recommandés

Installez ces plugins lors de la configuration initiale :

**Essentiels** :
- Kubernetes Plugin
- Docker Pipeline
- Git Plugin
- Pipeline
- Credentials Binding

**Qualité de code** :
- SonarQube Scanner
- Checkstyle
- JaCoCo

**Intégration** :
- Nexus Artifact Uploader
- Email Extension
- Slack Notification

**Sécurité** :
- OWASP Dependency-Check
- Role-based Authorization Strategy

### Configuration du plugin Kubernetes

1. Aller dans **Manage Jenkins** > **Configure System**
2. Chercher **Cloud** > **Add a new cloud** > **Kubernetes**
3. Configuration :
   ```
   Name: kubernetes
   Kubernetes URL: https://kubernetes.default
   Kubernetes Namespace: devops
   Jenkins URL: http://jenkins:8080/jenkins
   Jenkins tunnel: jenkins:50000
   ```

4. Ajouter un Pod Template :
   ```yaml
   Name: jenkins-agent
   Namespace: devops
   Labels: jenkins-agent
   
   Container Template:
     Name: jnlp
     Docker image: jenkins/inbound-agent:latest
     Working directory: /home/jenkins/agent
     Command to run: <empty>
     Arguments to pass: <empty>
   ```

## 🔐 Configuration des credentials

### 1. Credentials pour le registry Docker

```bash
# Via l'interface Jenkins
Manage Jenkins > Manage Credentials > (global) > Add Credentials

Kind: Username with password
Scope: Global
Username: admin
Password: <nexus_password>
ID: registry-auth
Description: Nexus Docker Registry
```

### 2. Credentials pour Git

```bash
Kind: SSH Username with private key
Scope: Global
ID: git-ssh-key
Username: git
Private Key: <paste your private key>
```

### 3. Credentials pour SonarQube

```bash
Kind: Secret text
Scope: Global
Secret: <sonarqube_token>
ID: sonarqube-token
Description: SonarQube Authentication Token
```

## 📝 Configuration des outils

### Maven

```
Manage Jenkins > Global Tool Configuration > Maven

Name: maven_3.9.8
Install automatically: Yes
Version: 3.9.8
```

### JDK

```
Name: jdk_17
Install automatically: Yes
Version: jdk-17.0.2+8
```

### Docker

```
Name: docker
Install automatically: Yes
Version: latest
```

## 🔄 Agents Jenkins

### Option 1 : Agents statiques

Déployez l'agent statique :

```bash
# 1. Créer un agent dans Jenkins UI
# 2. Copier le secret généré
# 3. Mettre à jour jenkins-agent-secret dans jenkins-agent.yaml
# 4. Déployer
kubectl apply -f jenkins-agent.yaml
```

### Option 2 : Agents dynamiques (Recommandé)

Utilisez le plugin Kubernetes pour créer des agents à la demande :

```groovy
// Dans votre Jenkinsfile
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  containers:
  - name: maven
    image: maven:3.9.8-eclipse-temurin-17
    command:
    - cat
    tty: true
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }
    stages {
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn clean package'
                }
            }
        }
        stage('Docker Build') {
            steps {
                container('docker') {
                    sh 'docker build -t myapp:latest .'
                }
            }
        }
    }
}
```

## 🔧 Configuration avancée

### Backup automatique

Créez un CronJob pour sauvegarder Jenkins :

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: jenkins-backup
  namespace: devops
spec:
  schedule: "0 2 * * *"  # Tous les jours à 2h du matin
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: alpine:latest
            command:
            - /bin/sh
            - -c
            - |
              apk add --no-cache tar gzip
              tar czf /backup/jenkins-backup-$(date +%Y%m%d).tar.gz -C /var/jenkins_home .
              # Garder seulement les 7 derniers backups
              ls -t /backup/jenkins-backup-*.tar.gz | tail -n +8 | xargs rm -f
            volumeMounts:
            - name: jenkins-home
              mountPath: /var/jenkins_home
            - name: backup
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: jenkins-home
            persistentVolumeClaim:
              claimName: jenkins-pvc
          - name: backup
            hostPath:
              path: /backup/jenkins
```

### Configuration as Code (JCasC)

Utilisez le plugin Configuration as Code :

```yaml
# jenkins-casc-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jenkins-casc-config
  namespace: devops
data:
  jenkins.yaml: |
    jenkins:
      systemMessage: "Jenkins configuré via Kubernetes"
      numExecutors: 0
      securityRealm:
        local:
          allowsSignup: false
          users:
            - id: "admin"
              password: "${JENKINS_ADMIN_PASSWORD}"
      authorizationStrategy:
        globalMatrix:
          permissions:
            - "Overall/Administer:admin"
            - "Overall/Read:authenticated"
    
    credentials:
      system:
        domainCredentials:
          - credentials:
              - usernamePassword:
                  scope: GLOBAL
                  id: "registry-auth"
                  username: "admin"
                  password: "${NEXUS_PASSWORD}"
    
    unclassified:
      location:
        url: "https://jenkins.local"
```

## 📊 Monitoring

### Prometheus metrics

Installez le plugin Prometheus et exposez les métriques :

```yaml
# ServiceMonitor pour Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: jenkins
  namespace: devops
spec:
  selector:
    matchLabels:
      app: jenkins
  endpoints:
  - port: http
    path: /jenkins/prometheus
```

## 🐛 Troubleshooting

### Jenkins ne démarre pas

```bash
# Vérifier les logs
kubectl logs -n devops -l app=jenkins

# Vérifier les événements
kubectl describe pod -n devops -l app=jenkins

# Vérifier le PVC
kubectl get pvc -n devops jenkins-pvc
```

### Problème de permissions

```bash
# Vérifier les permissions du volume
kubectl exec -n devops -it <jenkins-pod> -- ls -la /var/jenkins_home

# Corriger les permissions si nécessaire
kubectl exec -n devops -it <jenkins-pod> -- chown -R 1000:1000 /var/jenkins_home
```

### Agents ne se connectent pas

```bash
# Vérifier la connectivité
kubectl exec -n devops -it <agent-pod> -- nc -zv jenkins 50000

# Vérifier les logs de l'agent
kubectl logs -n devops -l app=jenkins-agent
```

## 📚 Références

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Configuration as Code](https://github.com/jenkinsci/configuration-as-code-plugin)

