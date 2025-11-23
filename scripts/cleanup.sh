#!/bin/bash

###############################################################################
# Script de nettoyage de l'infrastructure Kubernetes
# ATTENTION: Ce script supprime TOUTES les ressources déployées
# Usage: ./cleanup.sh [--force]
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"
FORCE=false

# Parser les arguments
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

# Confirmation
if [ "$FORCE" = false ]; then
    echo ""
    log_error "⚠️  ATTENTION: Ce script va SUPPRIMER toutes les ressources Kubernetes!"
    log_error "⚠️  Cela inclut:"
    echo "  - Tous les pods et déploiements"
    echo "  - Toutes les données dans les PersistentVolumes"
    echo "  - Tous les secrets et configurations"
    echo ""
    read -p "Êtes-vous ABSOLUMENT sûr de vouloir continuer? Tapez 'DELETE' pour confirmer: " -r
    echo
    if [[ ! $REPLY == "DELETE" ]]; then
        log_info "Nettoyage annulé"
        exit 0
    fi
fi

log_warning "Début du nettoyage..."

# Supprimer l'infrastructure
log_info "Suppression de l'infrastructure..."
kubectl delete -f "$K8S_DIR/infrastructure/" --recursive --ignore-not-found=true

# Supprimer les ConfigMaps et Secrets
log_info "Suppression des ConfigMaps et Secrets..."
kubectl delete -f "$K8S_DIR/base/configmaps/" --ignore-not-found=true
kubectl delete -f "$K8S_DIR/base/secrets/" --ignore-not-found=true

# Supprimer les PV et PVC
log_info "Suppression des volumes..."
kubectl delete pvc --all -n devops --ignore-not-found=true
kubectl delete -f "$K8S_DIR/base/storage/" --ignore-not-found=true

# Supprimer les namespaces (cela supprimera tout ce qui reste)
log_info "Suppression des namespaces..."
kubectl delete -f "$K8S_DIR/namespaces/" --ignore-not-found=true

log_info "Nettoyage terminé!"
log_warning "Note: Les données sur les nœuds (dans /mnt/k8s-storage/) n'ont pas été supprimées."
log_warning "Pour les supprimer, exécutez manuellement sur chaque nœud:"
echo "  sudo rm -rf /mnt/k8s-storage/*"

