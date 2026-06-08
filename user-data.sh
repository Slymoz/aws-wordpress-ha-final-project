#!/bin/bash
set -euo pipefail

# Redirection globale des sorties vers un fichier log pour audit
exec > >(tee /var/log/wordpress-user-data.log | logger -t wordpress-user-data -s 2>/dev/console) 2>&1

DB_NAME="${db_name}"
DB_USER="${db_username}"
DB_PASSWORD="${db_password}"
DB_HOST="${db_host}"
DB_PORT="${db_port}"

# Mise à jour et package système (écrit à la suite de façon simple)
dnf upgrade -y
dnf install -y wget httpd php-fpm php-mysqli php-json php php-devel gzip openssl tar mariadb105

# Activation des daemons Web et PHP
systemctl start httpd
systemctl enable httpd
systemctl start php-fpm
systemctl enable php-fpm

# Gestion des permissions pour l'administration Apache/EC2-User
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

# Boucle active d'attente de disponibilité du service managé RDS (Max 10 minutes)
for attempt in $(seq 1 60); do
  if mysql -h "$${DB_HOST}" -P "$${DB_PORT}" -u "$${DB_USER}" -p"$${DB_PASSWORD}" "$${DB_NAME}" -e "SELECT 1;" >/dev/null 2>&1; then
    echo "RDS database engine connection verified successfully."
    break
  fi
  echo "Waiting for RDS instance availability... Attempt $${attempt}/60"
  sleep 10
done

# Téléchargement et extraction du package officiel WordPress
wget https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz
tar -xzf /tmp/latest.tar.gz -C /tmp
rm -rf /var/www/html/*
cp -r /tmp/wordpress/* /var/www/html/
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

# Remplacement des ancres de configuration par les variables AWS d'exécution
replace_placeholder() {
  sed -i "s|$1|$2|g" /var/www/html/wp-config.php
}
replace_placeholder "database_name_here" "$${DB_NAME}"
replace_placeholder "username_here" "$${DB_USER}"
replace_placeholder "password_here" "$${DB_PASSWORD}"
replace_placeholder "localhost" "$${DB_HOST}:$${DB_PORT}"

# Injection de la structure HTML d'atterrissage pour le Health Check de l'ALB
cat > /var/www/html/index.html <<EOF
<h1>WordPress HA Cluster Node</h1>
<p>Status: Operating Healthy</p>
<p>Database Destination Host: $${DB_HOST}</p>
EOF

# Configuration finale des surcharges Apache et redémarrage des services
sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
chown -R apache:apache /var/www/html
systemctl restart php-fpm
systemctl restart httpd
