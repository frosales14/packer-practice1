#!/bin/bash
set -e

# 1. Actualizar e instalar herramientas base
sudo apt-get update
sudo apt-get install -y nginx git curl

# 2. Instalar Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# 3. Instalar PM2 globalmente
sudo npm install -g pm2

# 4. Preparar el directorio de la aplicación
REPO_URL="https://github.com/frosales14/node-app-herramientas-devops-demo"
APP_DIR="/var/www/app"

echo "--- Clonando repositorio ---"
sudo rm -rf $APP_DIR
sudo git clone $REPO_URL $APP_DIR

# Asignar permisos al usuario 'ubuntu'
APP_USER=$(whoami) # O usar $SUDO_USER si la línea está dentro de un bloque sudo
sudo chown -R $APP_USER:$APP_USER $APP_DIR

# 5. Instalar dependencias
cd $APP_DIR
echo "--- Instalando dependencias (npm install) ---"
sudo -u $APP_USER npm install

# 6. INICIAR LA APP (Aquí estaba el error)
echo "--- Iniciando aplicación: app/server.js ---"
if [ -f "app/server.js" ]; then
    sudo -u $APP_USER pm2 start app/server.js --name "app"
else
    echo "ERROR CRÍTICO: No se encontró app/server.js en $(pwd)"
    ls -R
    exit 1
fi

# 7. Configurar Persistencia de PM2
echo "--- Configurando persistencia de PM2 ---"
sudo -u $APP_USER pm2 save

STARTUP_CMD=$(sudo -u $APP_USER pm2 startup systemd | grep "sudo env")
if [ -n "$STARTUP_CMD" ]; then
    echo "Ejecutando startup: $STARTUP_CMD"
    eval $STARTUP_CMD
    sudo -u $APP_USER pm2 save
else
    echo "ADVERTENCIA: No se pudo generar el startup automático."
fi

# 8. Configurar Nginx como Proxy Inverso
echo "--- Configurando Nginx ---"
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Reiniciar Nginx
sudo nginx -t
sudo systemctl restart nginx

echo "--- Instalación Completa ---"