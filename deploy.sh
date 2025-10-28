#!/bin/bash

# Script de deployment para AWS User Group Oaxaca PoC
# Autor: Pablo Galeana
# Descripción: Build, push y deploy automatizado con tag 'latest'

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
PROJECT_NAME="overflow"
ENVIRONMENT="${1:-development}"
REGION="us-east-1"
IMAGE_TAG="latest"
DOCKERFILE_PATH="./docker"

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

log " Iniciando deployment para AWS User Group Oaxaca PoC"
log " Configuración:"
log "   - Proyecto: $PROJECT_NAME"
log "   - Entorno: $ENVIRONMENT"
log "   - Región: $REGION"
log "   - Tag de imagen: $IMAGE_TAG"

# Verificar dependencias
log " Verificando dependencias..."
command -v docker >/dev/null 2>&1 || { error "Docker no está instalado"; exit 1; }
command -v aws >/dev/null 2>&1 || { error "AWS CLI no está instalado"; exit 1; }
command -v terraform >/dev/null 2>&1 || { error "Terraform no está instalado"; exit 1; }

# Verificar configuración AWS
log " Verificando configuración AWS..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    error "No se puede autenticar con AWS. Configure sus credenciales."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log " Autenticado en AWS Account: $ACCOUNT_ID"

# Obtener información del ECR
ECR_REPO_NAME="${PROJECT_NAME}-app"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
ECR_URI="${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"

log "📦 Registry ECR: $ECR_URI"

# Paso 1: Build de la imagen Docker
log "🔨 Construyendo imagen Docker..."
cd "$DOCKERFILE_PATH"

if ! docker build -t "${PROJECT_NAME}-app:${IMAGE_TAG}" .; then
    error "Falló la construcción de la imagen Docker"
    exit 1
fi

success " Imagen Docker construida exitosamente"

# Paso 2: Autenticación con ECR
log " Autenticando con ECR..."
if ! aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"; then
    error "Falló la autenticación con ECR"
    exit 1
fi

success " Autenticado con ECR"

# Paso 3: Tag de la imagen para ECR
log " Etiquetando imagen para ECR..."
docker tag "${PROJECT_NAME}-app:${IMAGE_TAG}" "$ECR_URI"

# Paso 4: Push de la imagen
log " Subiendo imagen a ECR..."
if ! docker push "$ECR_URI"; then
    error "Falló el push de la imagen a ECR"
    exit 1
fi

success " Imagen subida exitosamente a ECR"

# Paso 5: Deploy con Terraform
log "🏗️ Desplegando infraestructura con Terraform..."
cd "../environments/$ENVIRONMENT"

# Inicializar Terraform si es necesario
if [[ ! -d ".terraform" ]]; then
    log "🔧 Inicializando Terraform..."
    terraform init
fi

# Planificar cambios
log " Planificando cambios..."
if ! terraform plan -out=tfplan; then
    error "Falló la planificación de Terraform"
    exit 1
fi

# Aplicar cambios
log " Aplicando cambios..."
if ! terraform apply -auto-approve tfplan; then
    error "Falló la aplicación de Terraform"
    exit 1
fi

success " Infraestructura desplegada exitosamente"

# Obtener información del deployment
log " Obteniendo información del deployment..."
EC2_PUBLIC_IP=$(terraform output -raw ec2_public_ip 2>/dev/null || echo "No disponible")
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "No disponible")

log " Deployment completado exitosamente!"
log ""
log " Información del deployment:"
log "    Aplicación web: http://$EC2_PUBLIC_IP"
log "    Code Server: http://$EC2_PUBLIC_IP:8080"
log "    RDS Endpoint: $RDS_ENDPOINT"
log "    Imagen Docker: $ECR_URI"
log ""
log " Credenciales por defecto:"
log "   - Code Server Password: ummaoaxaca"
log "   - RDS Username: postgres"
log "   - RDS Password: ummaoaxaca"
log ""
success " ¡PoC lista para la conferencia AWS User Group Oaxaca!"

# Limpiar archivos temporales
rm -f tfplan
