# AWS User Group Oaxaca - PoC Demo 🚀

## Infrastructure as Code con Terraform + Docker + AWS

Esta es una demostración completa de Infrastructure as Code usando Terraform, Docker y servicios AWS para la conferencia **AWS User Group Oaxaca**.

### 🎯 Objetivo de la PoC

Demostrar un flujo completo de deployment automatizado que incluye:
- **Docker**: Contenedor optimizado con Alpine Linux
- **AWS ECR**: Registry privado para imágenes Docker
- **AWS EC2**: Instancia con IAM roles para acceso a ECR
- **AWS RDS**: Base de datos PostgreSQL en VPC privada
- **AWS VPC**: Red privada con subnets públicas y privadas
- **Terraform**: Infrastructure as Code para automatización

### 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Internet      │    │   EC2 Instance  │    │   RDS Postgres  │
│                 │    │                 │    │                 │
│  Port 80 (HTTP) │◄───┤  Docker Container│◄───┤   Port 5432     │
│  Port 8080 (CS) │    │  - Apache       │    │   Private Subnet│
└─────────────────┘    │  - Code-Server  │    └─────────────────┘
                       │  - ECR Access   │
                       └─────────────────┘
                                │
                       ┌─────────────────┐
                       │   ECR Registry  │
                       │   overflow-app  │
                       │   :latest       │
                       └─────────────────┘
```

### 🚀 Deployment Rápido

#### Prerrequisitos
- AWS CLI configurado
- Docker instalado
- Terraform >= 1.0

#### Comando de Deployment
```bash
# Hacer ejecutable el script
chmod +x deploy.sh

# Deployar en desarrollo
./deploy.sh development

# Deployar en staging
./deploy.sh staging

# Deployar en producción
./deploy.sh production
```

### 📋 Lo que hace el script `deploy.sh`

1. **🔨 Build**: Construye la imagen Docker optimizada
2. **🏷️ Tag**: Etiqueta la imagen con `latest`
3. **📤 Push**: Sube la imagen al ECR registry
4. **🏗️ Deploy**: Despliega la infraestructura con Terraform
5. **✅ Verify**: Verifica que todo esté funcionando

### 🌐 Acceso a la Aplicación

Una vez desplegado, tendrás acceso a:

- **Aplicación Web**: `http://[EC2_PUBLIC_IP]`
- **Code Server**: `http://[EC2_PUBLIC_IP]:8080`
- **Credenciales**:
  - Code Server Password: `ummaoaxaca`
  - RDS Username: `postgres`
  - RDS Password: `ummaoaxaca`

### 🛠️ Servicios AWS Utilizados

| Servicio | Propósito | Configuración |
|----------|-----------|---------------|
| **ECR** | Registry de imágenes Docker | Repositorio privado con lifecycle policy |
| **EC2** | Instancia de aplicación | t3.micro con IAM roles |
| **RDS** | Base de datos PostgreSQL | db.t4g.micro en subnet privada |
| **VPC** | Red privada virtual | 3 AZs con subnets públicas/privadas |
| **IAM** | Roles y políticas | ECR read-only + SSM core |
| **Security Groups** | Firewall | HTTP, SSH, PostgreSQL |

### 📁 Estructura del Proyecto

```
umma-oaxaca/
├── docker/                    # Configuración Docker
│   ├── Dockerfile            # Imagen Alpine optimizada
│   ├── entrypoint.sh         # Script de inicio
│   └── apache-hello-world/   # Aplicación web
├── modules/micro-talent/     # Módulo Terraform
│   ├── main.tf              # Recursos AWS
│   ├── variables.tf         # Variables del módulo
│   └── locals.tf            # Configuración local
├── environments/             # Configuraciones por entorno
│   ├── development/         # Config dev
│   ├── staging/            # Config staging
│   └── production/          # Config prod
├── main.tf                  # Configuración principal
├── variables.tf             # Variables globales
└── deploy.sh               # Script de deployment
```

### 🔧 Optimizaciones para la PoC

#### Dockerfile Optimizado
- **Base**: `httpd:2.4-alpine` (imagen ligera)
- **Tamaño**: ~50MB vs ~500MB (Ubuntu)
- **Tiempo de build**: ~2 minutos vs ~10 minutos

#### Terraform Modular
- **Reutilizable**: Módulo independiente
- **Escalable**: Fácil agregar nuevos entornos
- **Mantenible**: Separación de responsabilidades

#### Script Automatizado
- **Un comando**: `./deploy.sh development`
- **Validaciones**: Verifica dependencias y configuración
- **Logs detallados**: Seguimiento completo del proceso
- **Manejo de errores**: Rollback automático en caso de fallo

### 🎪 Demo en Vivo

Para la conferencia, el flujo será:

1. **Mostrar el código**: Estructura del proyecto
2. **Ejecutar deploy**: `./deploy.sh development`
3. **Verificar servicios**: Acceso web y code-server
4. **Mostrar infraestructura**: AWS Console
5. **Cleanup**: Destruir recursos

### 🧹 Cleanup

Para limpiar los recursos después de la demo:

```bash
cd environments/development
terraform destroy -auto-approve
```

### 👨‍💻 Autor

**Pablo Galeana**  
AWS User Group Oaxaca  
*Infrastructure as Code Specialist*

---

### 📚 Recursos Adicionales

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

*Esta PoC demuestra las mejores prácticas de Infrastructure as Code para aplicaciones containerizadas en AWS.*
