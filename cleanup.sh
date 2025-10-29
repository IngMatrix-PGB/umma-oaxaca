#!/usr/bin/env bash
set -euo pipefail

# ---- Config mínima (personaliza si quieres) ----
ENVIRONMENT="${1:-development}"     # development|staging|production
REGION="${REGION:-us-east-1}"
TF_BACKEND_FILE="${TF_BACKEND_FILE:-environments/${ENVIRONMENT}/backend.hcl}"
TF_VARS_FILE="${TF_VARS_FILE:-environments/${ENVIRONMENT}/terraform.tfvars}"
ECR_REPO_NAME="${ECR_REPO_NAME:-overflow-app}"  # Debe coincidir con el que uses en CI/Terraform

# ---- Helpers simples (sin colores para menos ruido) ----
log()    { echo "[INFO]  $*"; }
warn()   { echo "[WARN]  $*"; }
error()  { echo "[ERROR] $*" >&2; }
confirm(){ read -r -p "$1 (yes/no): " ans; [[ "$ans" == "yes" ]]; }

# ---- Validaciones ----
if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
  error "Entorno no válido: $ENVIRONMENT"
  exit 1
fi

command -v aws >/dev/null || { error "AWS CLI no instalado"; exit 1; }
command -v terraform >/dev/null || { error "Terraform no instalado"; exit 1; }

log "Autenticando contra AWS..."
aws sts get-caller-identity >/dev/null || { error "Credenciales AWS inválidas"; exit 1; }
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
log "Cuenta: $ACCOUNT_ID  Región: $REGION  Entorno: $ENVIRONMENT"

warn "Esto destruirá TODOS los recursos de Terraform del entorno '$ENVIRONMENT'."
warn "Incluye EC2, RDS, VPC, SGs, etc. También eliminará imágenes y repo ECR '$ECR_REPO_NAME'."
confirm "¿Deseas continuar?" || { log "Cancelado."; exit 0; }

# ---- Terraform destroy ----
ENV_DIR="environments/${ENVIRONMENT}"
[[ -d "$ENV_DIR" ]] || { error "No existe $ENV_DIR"; exit 1; }

pushd "$ENV_DIR" >/dev/null

log "Inicializando Terraform..."
if [[ -f "../${TF_BACKEND_FILE##*/}" ]]; then
  # Si llamas desde environments/$ENVIRONMENT, soporta backend en ../backend.hcl
  terraform init -backend-config="../${TF_BACKEND_FILE##*/}"
elif [[ -f "../../${TF_BACKEND_FILE}" ]]; then
  terraform init -backend-config="../../${TF_BACKEND_FILE}"
else
  # Sin backend explícito: init simple (local state)
  terraform init
fi

log "Destruyendo infraestructura..."
if [[ -f "../${TF_VARS_FILE##*/}" ]]; then
  terraform destroy -auto-approve -var-file="../${TF_VARS_FILE##*/}"
elif [[ -f "../../${TF_VARS_FILE}" ]]; then
  terraform destroy -auto-approve -var-file="../../${TF_VARS_FILE}"
else
  terraform destroy -auto-approve
fi

popd >/dev/null
log "Infra destruida."

# ---- ECR cleanup con paginación ----
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

repo_exists() {
  aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$REGION" >/dev/null 2>&1
}

if repo_exists; then
  log "Eliminando imágenes de ECR ($ECR_REPO_NAME)..."
  # Paginar list-images (1000 por página como máximo)
  NEXT_TOKEN=""
  while :; do
    if [[ -z "$NEXT_TOKEN" ]]; then
      PAGE=$(aws ecr list-images --repository-name "$ECR_REPO_NAME" --region "$REGION" \
              --query 'imageIds' --output json)
    else
      PAGE=$(aws ecr list-images --repository-name "$ECR_REPO_NAME" --region "$REGION" \
              --query 'imageIds' --output json --starting-token "$NEXT_TOKEN")
    fi

    if [[ "$PAGE" != "[]" ]]; then
      aws ecr batch-delete-image --repository-name "$ECR_REPO_NAME" \
         --image-ids "$PAGE" --region "$REGION" >/dev/null || true
      log "Página de imágenes eliminada."
    fi

    # obtener next token
    RAW=$(aws ecr list-images --repository-name "$ECR_REPO_NAME" --region "$REGION" --output json || echo "{}")
    NEXT_TOKEN=$(printf '%s' "$RAW" | grep -o '"nextToken":[^,}]*' | cut -d: -f2- | tr -d ' "')
    [[ -z "$NEXT_TOKEN" ]] && break
  done

  log "Eliminando repositorio ECR..."
  aws ecr delete-repository --repository-name "$ECR_REPO_NAME" --region "$REGION" --force >/dev/null || true
  log "ECR limpiado."
else
  log "Repositorio ECR '$ECR_REPO_NAME' no existe o ya fue eliminado."
fi

# ---- Limpieza de archivos locales de Terraform (si quedaron) ----
log "Limpiando artefactos locales..."
rm -rf "${ENV_DIR}/.terraform" "${ENV_DIR}/.terraform.lock.hcl" "${ENV_DIR}/tfplan" 2>/dev/null || true
log "Listo."

log "Cleanup completado ✅"
