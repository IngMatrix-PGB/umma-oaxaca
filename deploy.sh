#!/usr/bin/env bash
set -euo pipefail

# ---- Config ----
PROJECT_NAME="${PROJECT_NAME:-overflow}"
ENVIRONMENT="${1:-development}"               # development|staging|production
REGION="${REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DOCKER_DIR="${DOCKER_DIR:-./docker}"

TF_BACKEND_FILE="${TF_BACKEND_FILE:-environments/${ENVIRONMENT}/backend.hcl}"
TF_VARS_FILE="${TF_VARS_FILE:-environments/${ENVIRONMENT}/terraform.tfvars}"
TF_PARALLELISM="${TF_PARALLELISM:-10}"

# Repo ECR (coherente con cleanup)
ECR_REPO_NAME="${ECR_REPO_NAME:-${PROJECT_NAME}-app}"

# ---- Helpers ----
log()   { echo "[INFO]  $*"; }
error() { echo "[ERROR] $*" >&2; }

# ---- Validaciones ----
if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
  error "Entorno no válido: $ENVIRONMENT"
  exit 1
fi

command -v docker >/dev/null   || { error "Docker no instalado"; exit 1; }
command -v aws >/dev/null      || { error "AWS CLI no instalado"; exit 1; }
command -v terraform >/dev/null|| { error "Terraform no instalado"; exit 1; }

aws sts get-caller-identity >/dev/null || { error "Credenciales AWS inválidas"; exit 1; }
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"

log "Cuenta: $ACCOUNT_ID  Región: $REGION  Entorno: $ENVIRONMENT"
log "ECR target: ${IMAGE_URI}"

# ---- Crear repo ECR si no existe ----
if ! aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$REGION" >/dev/null 2>&1; then
  log "Creando repositorio ECR '$ECR_REPO_NAME'..."
  aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "$REGION" >/dev/null
fi

# ---- Login ECR ----
log "Login ECR..."
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY" >/dev/null

# ---- Build & push ----
log "Construyendo imagen..."
pushd "$DOCKER_DIR" >/dev/null
docker build -t "${PROJECT_NAME}-app:${IMAGE_TAG}" .
docker tag   "${PROJECT_NAME}-app:${IMAGE_TAG}" "$IMAGE_URI"
docker push  "$IMAGE_URI"
popd >/dev/null
log "Imagen publicada: $IMAGE_URI"

# ---- Terraform apply ----
ENV_DIR="environments/${ENVIRONMENT}"
[[ -d "$ENV_DIR" ]] || { error "No existe ${ENV_DIR}"; exit 1; }

pushd "$ENV_DIR" >/dev/null

log "Inicializando Terraform..."
if [[ -f "../${TF_BACKEND_FILE##*/}" ]]; then
  terraform init -backend-config="../${TF_BACKEND_FILE##*/}"
elif [[ -f "../../${TF_BACKEND_FILE}" ]]; then
  terraform init -backend-config="../../${TF_BACKEND_FILE}"
else
  terraform init
fi

PLAN_ARGS=(-var "docker_image=${IMAGE_URI}")
if [[ -f "../${TF_VARS_FILE##*/}" ]]; then
  PLAN_ARGS+=(-var-file="../${TF_VARS_FILE##*/}")
elif [[ -f "../../${TF_VARS_FILE}" ]]; then
  PLAN_ARGS+=(-var-file="../../${TF_VARS_FILE}")
fi

log "Planificando..."
terraform plan -parallelism="${TF_PARALLELISM}" "${PLAN_ARGS[@]}" -out=tfplan

log "Aplicando..."
terraform apply -parallelism="${TF_PARALLELISM}" -auto-approve tfplan

# ---- Outputs útiles ----
EC2_PUBLIC_IP="$(terraform output -raw ec2_public_ip 2>/dev/null || true)"
RDS_ENDPOINT="$(terraform output -raw rds_endpoint 2>/dev/null || true)"

log "Deployment OK ✅"
[[ -n "$EC2_PUBLIC_IP" ]] && \
  log "Web:        http://${EC2_PUBLIC_IP}" && \
  log "code-server: http://${EC2_PUBLIC_IP}:8080"
[[ -n "$RDS_ENDPOINT" ]] && log "RDS:        ${RDS_ENDPOINT}"
log "Imagen:     ${IMAGE_URI}"

popd >/dev/null
