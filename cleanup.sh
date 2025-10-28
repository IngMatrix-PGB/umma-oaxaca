#!/bin/bash

# Script de cleanup para AWS User Group Oaxaca PoC
# Autor: Pablo Galeana
# Descripción: Limpia todos los recursos creados durante la demo

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Variables de configuración
ENVIRONMENT="${1:-development}"
REGION="us-east-1"

# Validar argumentos
if [[ $# -eq 0 ]]; then
    echo "Uso: $0 <environment>"
    echo "Entornos disponibles: development, staging, production"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
    error "Entorno '$ENVIRONMENT' no válido. Use: development, staging, o production"
    exit 1
fi

log "🧹 Iniciando cleanup para AWS User Group Oaxaca PoC"
log "📋 Entorno: $ENVIRONMENT"

# Verificar dependencias
log "🔍 Verificando dependencias..."
command -v aws >/dev/null 2>&1 || { error "AWS CLI no está instalado"; exit 1; }
command -v terraform >/dev/null 2>&1 || { error "Terraform no está instalado"; exit 1; }

# Verificar configuración AWS
log "🔐 Verificando configuración AWS..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    error "No se puede autenticar con AWS. Configure sus credenciales."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log "✅ Autenticado en AWS Account: $ACCOUNT_ID"

# Confirmar antes de destruir
warning "⚠️  ADVERTENCIA: Esto destruirá TODOS los recursos del entorno '$ENVIRONMENT'"
warning "⚠️  Esto incluye: EC2, RDS, VPC, ECR, Security Groups, etc."
echo ""
read -p "¿Estás seguro de que quieres continuar? (escribe 'yes' para confirmar): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    log "❌ Operación cancelada por el usuario"
    exit 0
fi

# Cambiar al directorio del entorno
ENVIRONMENT_DIR="environments/$ENVIRONMENT"
if [[ ! -d "$ENVIRONMENT_DIR" ]]; then
    error "Directorio de entorno '$ENVIRONMENT_DIR' no encontrado"
    exit 1
fi

cd "$ENVIRONMENT_DIR"

# Destruir infraestructura con Terraform
log "🏗️ Destruyendo infraestructura con Terraform..."
if ! terraform destroy -auto-approve; then
    error "Falló la destrucción de la infraestructura"
    exit 1
fi

success "✅ Infraestructura destruida exitosamente"

# Limpiar imágenes del ECR (opcional)
log "🐳 Limpiando imágenes del ECR..."
ECR_REPO_NAME="overflow-app"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Verificar si el repositorio existe
if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$REGION" >/dev/null 2>&1; then
    log "🗑️ Eliminando imágenes del repositorio ECR..."
    
    # Listar y eliminar todas las imágenes
    IMAGE_IDS=$(aws ecr list-images --repository-name "$ECR_REPO_NAME" --region "$REGION" --query 'imageIds[*]' --output json 2>/dev/null || echo "[]")
    
    if [[ "$IMAGE_IDS" != "[]" ]]; then
        aws ecr batch-delete-image --repository-name "$ECR_REPO_NAME" --image-ids "$IMAGE_IDS" --region "$REGION" >/dev/null 2>&1 || true
        success "✅ Imágenes del ECR eliminadas"
    else
        log "ℹ️ No hay imágenes en el repositorio ECR"
    fi
    
    # Eliminar el repositorio ECR
    log "🗑️ Eliminando repositorio ECR..."
    aws ecr delete-repository --repository-name "$ECR_REPO_NAME" --region "$REGION" --force >/dev/null 2>&1 || true
    success "✅ Repositorio ECR eliminado"
else
    log "ℹ️ Repositorio ECR no encontrado o ya eliminado"
fi

# Limpiar archivos temporales
log "🧽 Limpiando archivos temporales..."
rm -f tfplan
rm -rf .terraform/
rm -f .terraform.lock.hcl

success "✅ Archivos temporales eliminados"

log "🎉 Cleanup completado exitosamente!"
log ""
log "📋 Resumen del cleanup:"
log "   🏗️ Infraestructura Terraform: DESTRUIDA"
log "   🐳 Repositorio ECR: ELIMINADO"
log "   🧽 Archivos temporales: LIMPIADOS"
log ""
success "✨ Entorno '$ENVIRONMENT' completamente limpio"

# Mostrar costo estimado ahorrado
log ""
log "💰 Costo estimado ahorrado:"
log "   - EC2 t3.micro: ~$8.50/mes"
log "   - RDS db.t4g.micro: ~$12.50/mes"
log "   - NAT Gateway: ~$32.40/mes"
log "   - Total estimado: ~$53.40/mes"
log ""
success "🎊 ¡Demo completada y recursos liberados!"
