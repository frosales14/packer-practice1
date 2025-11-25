#!/bin/bash
set -e # Detener el script si hay un error

# --- CONFIGURACIÓN DE AWS ---
REGION="us-east-2"                        # Tu región de AWS
INSTANCE_TYPE="t3.micro"                  # Tipo de instancia
KEY_NAME="unir"                           # Nombre de tu par de claves SSH (la que usaste en el log)
SECURITY_GROUP_IDS="sg-0ee6cba86467001f5"      # ID del Grupo de Seguridad (el que tiene abiertos 22 y 80)
SUBNET_ID="subnet-02049f2321bbd36f5"           # ID de la Subnet de tu VPC

# 1. CONSTRUIR LA AMI USANDO PACKER (Ejercicio 1)
echo "--- 1. Ejecutando Packer Build para crear la AMI ---"
PACKER_OUTPUT=$(packer build -machine-readable aws-ubuntu.pkr.hcl)

# 2. CAPTURAR EL ID DE LA AMI GENERADA
# Buscamos la línea que contiene "artifact,0,id" y extraemos el ID de la AMI
AMI_ID=$(echo "$PACKER_OUTPUT" | grep 'artifact,0,id' | cut -d ',' -f 6 | cut -d ':' -f 2)

if [ -z "$AMI_ID" ]; then
    echo "ERROR: No se pudo obtener el ID de la AMI de la salida de Packer."
    exit 1
fi

echo "AMI Generada Exitosamente. ID: $AMI_ID"

# 3. DESPLIEGUE AUTOMÁTICO SIN INTERVENCIÓN MANUAL (Ejercicio 2)
echo "--- 2. Lanzando la instancia EC2 con la CLI de AWS ---"

RUN_INSTANCE_OUTPUT=$(
    aws ec2 run-instances \
    --region $REGION \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_IDS \
    --subnet-id $SUBNET_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Despliegue-Automatico-Packer}]'
)

# 4. EXTRACCIÓN DE IP PÚBLICA (Opcional, pero útil)
INSTANCE_ID=$(echo $RUN_INSTANCE_OUTPUT | jq -r '.Instances[0].InstanceId')
echo "Instancia lanzada. ID: $INSTANCE_ID. Esperando IP pública..."

# Espera hasta que la instancia esté en estado "running"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Obtiene la IP pública
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "--- ¡DESPLIEGUE COMPLETO Y AUTOMÁTICO! ---"
echo "La aplicación está disponible en: http://$PUBLIC_IP"
echo "La instancia es accesible por SSH en: ssh -i $KEY_NAME.pem ubuntu@$PUBLIC_IP"