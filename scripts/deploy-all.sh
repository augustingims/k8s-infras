#!/bin/bash

###############################################################################
# Script de déploiement complet de l'infrastructure Kubernetes
# Usage: ./deploy-all.sh [--skip-ingress] [--skip-apps]
###############################################################################

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour vérifier si kubectl est installé
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl n'est pas installé. Veuillez l'installer avant de continuer."
        exit 1
    fi
    log_success "kubectl est installé"
}

# Fonction pour vérifier la connexion au cluster
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes"
        exit 1
    fi
    log_success "Connexion au cluster établie"
}

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"
SKIP_INGRESS=false

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-ingress)
            SKIP_INGRESS=true
            shift
            ;;
        *)
            log_error "Argument inconnu: $1"
            echo "Usage: $0 [--skip-ingress] [--skip-apps]"
            exit 1
            ;;
    esac
done

# Vérifications préalables
log_info "Vérification des prérequis..."
check_kubectl
check_cluster

# Afficher les informations du cluster
log_info "Informations du cluster:"
kubectl get nodes

# Confirmation
echo ""
log_warning "Ce script va déployer l'infrastructure complète sur le cluster Kubernetes."
read -p "Voulez-vous continuer? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Déploiement annulé"
    exit 0
fi

###############################################################################
# 1. CRÉATION DES NAMESPACES
###############################################################################
log_info "Étape 1/7: Création des namespaces..."
kubectl apply -f "$K8S_DIR/namespaces/"
sleep 2
log_success "Namespaces créés"

###############################################################################
# 2. CRÉATION DU STOCKAGE
###############################################################################
log_info "Étape 2/7: Configuration du stockage..."
kubectl apply -f "$K8S_DIR/base/storage/storage-class.yaml"
kubectl apply -f "$K8S_DIR/base/storage/pv-devops.yaml"
sleep 2
log_success "Stockage configuré"

###############################################################################
# 3. CRÉATION DES SECRETS
###############################################################################
log_info "Étape 3/7: Création des secrets..."
kubectl apply -f "$K8S_DIR/base/secrets/"
sleep 2
log_success "Secrets créés"

###############################################################################
# 4. CRÉATION DES CONFIGMAPS
###############################################################################
log_info "Étape 4/7: Création des ConfigMaps..."
kubectl apply -f "$K8S_DIR/base/configmaps/"
sleep 2
log_success "ConfigMaps créés"

###############################################################################
# 5. DÉPLOIEMENT DE L'INFRASTRUCTURE
###############################################################################
log_info "Étape 5/7: Déploiement de l'infrastructure DevOps..."

# PostgreSQL
log_info "  - Déploiement de PostgreSQL (devops)..."
kubectl apply -f "$K8S_DIR/infrastructure/postgres/statefulset-devops.yaml"
kubectl apply -f "$K8S_DIR/infrastructure/postgres/pgadmin-devops.yaml"

# PostgreSQL Production
log_info "  - Déploiement de PostgreSQL (production)..."
kubectl apply -f "$K8S_DIR/infrastructure/postgres/statefulset-production.yaml"

# Attendre que PostgreSQL soit prêt
log_info "  - Attente du démarrage de PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n devops --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=postgres -n production --timeout=300s || true

# Jenkins
log_info "  - Déploiement de Jenkins..."
kubectl apply -f "$K8S_DIR/infrastructure/jenkins/deployment.yaml"

# Nexus
log_info "  - Déploiement de Nexus..."
kubectl apply -f "$K8S_DIR/infrastructure/nexus/deployment.yaml"

# SonarQube
log_info "  - Déploiement de SonarQube..."
kubectl apply -f "$K8S_DIR/infrastructure/sonarqube/deployment.yaml"

log_success "Infrastructure déployée"

###############################################################################
# 6. DÉPLOIEMENT DE L'INGRESS CONTROLLER
###############################################################################
if [ "$SKIP_INGRESS" = false ]; then
    log_info "Étape 6/7: Déploiement de l'Ingress Controller..."
    
    # Vérifier si Helm est installé
    if command -v helm &> /dev/null; then
        log_info "  - Installation de Nginx Ingress Controller via Helm..."
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
        helm repo update
        helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --set controller.service.type=NodePort \
            --set controller.service.nodePorts.http=30080 \
            --set controller.service.nodePorts.https=30443 \
            --wait
        
        log_info "  - Installation de Cert-Manager via Helm..."
        helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
        helm repo update
        helm upgrade --install cert-manager jetstack/cert-manager \
            --namespace cert-manager \
            --create-namespace \
            --version v1.14.0 \
            --set installCRDs=true \
            --wait
    else
        log_warning "Helm n'est pas installé. Installation manuelle de l'Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/baremetal/deploy.yaml
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
    fi
    
    # Attendre que l'Ingress Controller soit prêt
    log_info "  - Attente du démarrage de l'Ingress Controller..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s || true
    
    log_success "Ingress Controller déployé"
else
    log_warning "Étape 6/7: Déploiement de l'Ingress Controller ignoré"
fi

###############################################################################
# 7. VÉRIFICATION DU DÉPLOIEMENT
###############################################################################
log_info "Étape 7/7: Vérification du déploiement..."

echo ""
log_info "État des pods dans le namespace devops:"
kubectl get pods -n devops

echo ""
log_info "Services exposés:"
kubectl get svc -n devops

if [ "$SKIP_INGRESS" = false ]; then
    echo ""
    log_info "Ingress configurés:"
    kubectl get ingress -n devops
fi

echo ""
log_success "Déploiement terminé avec succès!"

echo ""
log_info "Prochaines étapes:"
echo "  1. Vérifier que tous les pods sont en état Running"
echo "  2. Récupérer les mots de passe initiaux (Jenkins, Nexus, etc.)"
echo "  3. Accéder aux services"
echo ""
log_info "Pour plus d'informations, consultez la documentation dans le dossier docs/"

