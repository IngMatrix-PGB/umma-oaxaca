Overflow AWS Lab — README

Este repo es una PoC para levantar una mini-plataforma en AWS con Terraform y Docker.

Los recursos estan parametrizado por ambiente (ej. development) y versionado en ECR (uso latest para dev).

Recursos generados

VPC (3 AZs): subredes públicas/privadas, IGW, NAT, tablas de ruteo.

Security Groups

EC2: 80/tcp abierto, 8080/tcp abierto (dev), SSH restringido por CIDR.

RDS: solo acepta del SG de EC2 en 5432/tcp.

ECR: repo overflow-app con escaneo y lifecycle (conserva últimas 10).

RDS Postgres 16: privado, en subredes privadas (sin exposición pública).

EC2 t4g.micro con:

IAM Role (ECR ReadOnly + SSM Core) e Instance Profile.

user_data que instala Docker, hace login a ECR, pull de la imagen y corre el contenedor:

Apache sirviendo un “hola mundo” en :80

code-server (VS Code Web) en :8080 con password por variable

Check opcional a Postgres (psql) y logs sencillos

Estructura rápida
environments/
  development/
    backend.hcl            
    terraform.tfvars       # Variables del ambiente dev
modules/
  micro-talent/            # Módulo raíz con VPC, EC2, ECR, RDS, SG, IAM
docker/
  Dockerfile               # Imagen (Ubuntu + Apache + .NET SDK + Java + Maven + psql + code-server)
  entrypoint.sh            # Arranca Apache y code-server, chequea RDS
  apache-hello-world/
    index.html             # Landing de prueba

Requisitos

Terraform >= 1.3

AWS CLI configurado

Permisos para usar S3 (backend), EC2, ECR, RDS, IAM, VPC, SSM

Cómo desplegar de manera manual :

Siempre apuntar al backend y a las vars del ambiente para este caso de estudio en development:

terraform init -backend-config="environments/development/backend.hcl"
terraform plan -var-file="environments/development/terraform.tfvars" -out=tfplan-non-production
terraform apply "tfplan-non-production"

Costos y limpieza

Esto crea NAT Gateway, RDS, EC2, etc.

Para limpiar:

terraform destroy -var-file="environments/development/terraform.tfvars"