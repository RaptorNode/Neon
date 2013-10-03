#!/bin/bash

mkdir ~/neon-install/
cd ~/neon-install/
touch ~/neon-install/install.log
exec 3>&1 > ~/neon-install/install.log 2>&1

############################################################
# Functions
############################################################

function status {
      echo $1;
      echo $1 >&3
}

function install {
      DEBIAN_FRONTEND=noninteractive apt-get -q -y install --allow-unauthenticated "$1"
      apt-get clean
}

function remove {
      /etc/init.d/"$1" stop
      service "$1" stop
      export DEBIAN_PRIORITY=critical
      export DEBIAN_FRONTEND=noninteractive
      apt-get -q -y remove "$1"
      apt-get clean
}

function slaughter_httpd {
      pkill apache
      pkill apache2
      aptitude -y purge ~i~napache
      apt-get --purge -y autoremove apache*
      apt-get remove apache2-utils
      
      kill -9 $( lsof -i:80 -t )
      x=$(($x + 1));
      
      update-rc.d -f apache2 remove
      update-rc.d -f apache remove
      update-rc.d -f nginx remove
      update-rc.d -f lighttpd remove
      update-rc.d -f httpd remove
}

function check_installs {
      if ! type -p $1 > /dev/null; then
            status "Unfortunatly $1 failed to install. Neon install aborting."
            exit 1
      fi
}

function check_sanity {
      # Do some sanity checking.
      if [ $(/usr/bin/id -u) != "0" ]
      then
            status "Neon must be installed as root. Please log in as root and try again."
            die 'Neon must be installed as root. Please log in as root and try again.'
      fi

      if [ ! -f /etc/debian_version ]
      then
            status "Neon must be installed as root. Please log in as root and try again."
            die "Neon must be installed on Debian 6.0."
      fi
}

function die {
      echo "ERROR: $1" > /dev/null 1>&2
      exit 1
}

check_sanity


############################################################
# Begin Installation
############################################################

status "====================================="
status "     Welcome to Neon Installation"
status "====================================="
status "Neon will remove any existing apache,"
status "nginx, mysql or php services you have"
status "installed upon this server. It will"
status "also delete all custom config files"
status "that you may have."
status " "
status "It is reccomended that you run this"
status "installer in a screen."
status " "
status "This script will begin installing"
status "Neon in 10 seconds. If you wish to"
status "cancel the install press CTRL + C"
sleep 10
status "Neon needs a bit of information before"
status "beginning the installation."
status " "
status "What hostname would you like to use (Example: server.yourdomain.com):"
read user_host

############################################################
# Begin Cleanup
############################################################

status " "
status "Begining cleanup..."

remove="apache2 apache* apache2* apache2-utils mysql* php* nginx lighttpd httpd* php5-fpm vsftpd proftpd exim qmail postfix sendmail dovecot"

slaughter_httpd
status "Cleanup Phase: 1 of 18"

for program in $remove
do
      remove $program
      x=$(($x + 1));
      status "Cleanup Phase: $x of 18"
done
apt-get autoremove

status " "
status "Cleanup completed."
status "Beginning installation phase 1 of 2"

############################################################
# Begin Install Phase 1
############################################################

echo "deb http://repo.neoncp.com/dotdeb stable all" >> /etc/apt/sources.list
echo "deb http://xi.rename-it.nl/debian/ stable-auto/dovecot-2.0 main" >> /etc/apt/sources.list
wget http://repo.neoncp.com/dotdeb/dotdeb.gpg
cat dotdeb.gpg | apt-key add -
rm -rf dotdeb.gpg
apt-get update
y=$(($y + 1));
status "Install: $y of 39"

install="postfix postfix-mysql dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql nginx php5 vim openssl php5-mysql zip unzip sqlite3 php-mdb2-driver-mysql php5-sqlite php5-curl php-pear php5-dev acl libcurl4-openssl-dev php5-gd php5-imagick php5-imap php5-mcrypt php5-xmlrpc php5-xsl php5-fpm libpcre3-dev build-essential php-apc git-core pdns-server pdns-backend-mysql host mysql-server phpmyadmin"

for program in $install
do
      install $program
      y=$(($y + 1));
      status "Install: $y of 39"
done

############################################################
# Perform Installation Checks
############################################################

check_installs nginx
check_installs php
check_installs git
check_installs mysql

############################################################
# Begin Configuration Phase 1
############################################################

status " "
status "Begining Configuration Phase: 1 of 2"

/etc/init.d/mysql stop
invoke-rc.d mysql stop
/etc/init.d/nginx stop
/etc/init.d/php5-fpm stop
status "Base Config: 1 / 13"

############################################################
# Download Neon
############################################################

mkdir /var/neon/
git clone -b develop-mail https://github.com/BlueVM/Neon.git /var/neon/

cd ~/neon-install/
status "Base Config: 2 / 13"

############################################################
# Create Folders
############################################################

touch /var/neon/data/log.txt
mkdir /var/neon/neonpanel/uploads
mkdir /var/neon/neonpanel/downloads
mkdir /home/root/

cd ~/neon-install/
status "Base Config: 3 / 13"

############################################################
# Generate Passwords
############################################################

mysqlpassword=`< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-32};`

cd ~/neon-install/
status "Base Config: 4 / 13"

############################################################
# Create Neon Configs
############################################################

cp /var/neon/data/config.example /var/neon/data/config.json
sed -i 's/databaseusernamehere/root/g' /var/neon/data/config.json
sed -i 's/databasepasswordhere/'${mysqlpassword}'/g' /var/neon/data/config.json
sed -i 's/databasenamehere/panel/g' /var/neon/data/config.json
sed -i 's/randomlygeneratedsalthere/'${salt}'/g' /var/neon/data/config.json
sed -i 's/hostnameforinstallhere/'${user_host}'/g' /var/neon/data/config.json

ssh-keygen -t rsa -N "" -f ~/neon-install/id_rsa
mkdir ~/.ssh/
cat id_rsa.pub >> ~/.ssh/authorized_keys
mv id_rsa /var/neon/data/
setfacl -Rm user:www-data:rwx /var/neon/*

cd ~/neon-install/
status "Base Config: 5 / 13"

############################################################
# Begin Mysql Configuration
############################################################

mv /etc/my.cnf /etc/my.cnf.backup
cp /var/neon/neonpanel/includes/configs/my.cnf /etc/my.cnf
/etc/init.d/mysql start

salt=`< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-32};`
mysqladmin -u root password $mysqlpassword

while ! mysql -u root -p$mysqlpassword  -e ";" ; do
       status "Unfortunatly mysql failed to install correctly. Neon installation aborting (Error #2)".
done

mysql -u root --password="$mysqlpassword" --execute="CREATE DATABASE IF NOT EXISTS panel;CREATE DATABASE IF NOT EXISTS dns;"
mysql -u root --password="$mysqlpassword" panel < /var/neon/data.sql

cd ~/neon-install/
status "Base Config: 6 / 13"

############################################################
# Begin PHP Configuration
############################################################

cp /var/neon/neonpanel/includes/configs/php.conf /etc/php5/fpm/pool.d/www.conf
mv /etc/php5/conf.d/apc.ini /etc/php5/apc.old
rm -rf /etc/php5/fpm/php.ini
cp /var/neon/neonpanel/includes/configs/php.ini /etc/php5/fpm/php.ini

cd ~/neon-install/
status "Base Config: 7 / 13"

############################################################
# Begin SSL Configuration
############################################################

mkdir /usr/ssl
cd /usr/ssl
openssl genrsa -out neon.key 1024
openssl rsa -in neon.key -out neon.pem
openssl req -new -key neon.pem -subj "/C=US/ST=Oregon/L=Portland/O=IT/CN=www.neonpanel.com" -out neon.csr
openssl x509 -req -days 365 -in neon.csr -signkey neon.pem -out neon.crt

cd ~/neon-install/
status "Base Config: 8 / 13"

############################################################
# Begin Nginx Configuration
############################################################

rm -rf /etc/nginx/sites-enabled/* 
mv /var/neon/neonpanel/includes/configs/nginx.neon.conf /etc/nginx/sites-enabled/nginx.neon.conf 
setfacl -Rm user:www-data:rwx /var/neon/*

cd ~/neon-install/
status "Base Config: 9 / 13"

############################################################
# Begin PHPMyAdmin Configuration
############################################################

mv /etc/phpmyadmin/config.inc.php /etc/phpmyadmin/config.old.inc.php
cp /var/neon/neonpanel/includes/configs/pma.php /usr/share/phpmyadmin/
cp /var/neon/neonpanel/includes/configs/pma.config.inc.php /etc/phpmyadmin/config.inc.php
sed -i 's/databasepasswordhere/'${mysqlpassword}'/g' /usr/share/phpmyadmin/pma.php

cd ~/neon-install/
status "Base Config: 10 / 13"

############################################################
# Begin PDNS Configuration
############################################################

mv /etc/powerdns/pdns.conf /etc/powerdns/pdns.old
cp /var/neon/neonpanel/includes/configs/pdns.conf /etc/powerdns/pdns.conf
sed -i 's/databasenamehere/dns/g' /etc/powerdns/pdns.conf
sed -i 's/databasepasswordhere/'${mysqlpassword}'/g' /etc/powerdns/pdns.conf
sed -i 's/databaseusernamehere/root/g' /etc/powerdns/pdns.conf

cd ~/neon-install/
status "Base Config: 11 / 13"

############################################################
# Begin Mail Configuration
############################################################

# Set up database
mailuserpass=`< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-32};`
mysql -p${mysqlpassword} -e 'CREATE DATABASE mailserver;'
mysql -p${mysqlpassword} -e "GRANT ALL ON mailserver.* TO 'mailuser'@'127.0.0.1' IDENTIFIED BY \"${mailuserpass}\";"
mysql -p${mysqlpassword} -e 'FLUSH PRIVILEGES;'
mysql -p${mysqlpassword} mailserver -e 'CREATE TABLE `virtual_domains` (  `id` int(11) NOT NULL auto_increment,  `name` varchar(50) NOT NULL,  PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;'
mysql -p${mysqlpassword} mailserver -e 'CREATE TABLE `virtual_users` (  `id` int(11) NOT NULL auto_increment,  `domain_id` int(11) NOT NULL,  `password` varchar(106) NOT NULL,  `email` varchar(100) NOT NULL,  PRIMARY KEY (`id`),  UNIQUE KEY `email` (`email`),  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE) ENGINE=InnoDB DEFAULT CHARSET=utf8;'
mysql -p${mysqlpassword} mailserver -e 'CREATE TABLE `virtual_aliases` (  `id` int(11) NOT NULL auto_increment,  `domain_id` int(11) NOT NULL,  `source` varchar(100) NOT NULL,  `destination` varchar(100) NOT NULL,  PRIMARY KEY (`id`),  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE) ENGINE=InnoDB DEFAULT CHARSET=utf8;'

# Set up Postfix config files
mkdir /etc/dovecot/conf.d
echo "smtpd_banner = \$myhostname ESMTP $mail_name (Ubuntu)
biff = no
append_dot_mydomain = no
readme_directory = no
smtpd_tls_cert_file=/etc/ssl/certs/dovecot.pem
smtpd_tls_key_file=/etc/ssl/private/dovecot.pem
smtpd_use_tls=yes
smtpd_tls_auth_only=no
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_recipient_restrictions =
        permit_sasl_authenticated,
        permit_mynetworks,
        reject_unauth_destination
virtual_transport = lmtp:unix:private/dovecot-lmtp
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf
myhostname = ${user_host}
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname
mydestination = localhost
relayhost =
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all" > /etc/postfix/main.cf
echo "user = mailuser
password = ${mailuserpass}
hosts = 127.0.0.1
dbname = mailserver
query = SELECT 1 FROM virtual_domains WHERE name='%s'" > /etc/postfix/mysql-virtual-mailbox-domains.cf
echo "user = mailuser
password = ${mailuserpass}
hosts = 127.0.0.1
dbname = mailserver
query = SELECT 1 FROM virtual_users WHERE email='%s'" > /etc/postfix/mysql-virtual-mailbox-maps.cf
echo "user = mailuser
password = ${mailuserpass}
hosts = 127.0.0.1
dbname = mailserver
query = SELECT destination FROM virtual_aliases WHERE source='%s'" > /etc/postfix/mysql-virtual-alias-maps.cf
echo "passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}
userdb {
  driver = static
  args = uid=vmail gid=vmail home=/var/mail/vhosts/%d/%n
}" > /etc/dovecot/conf.d/auth-sql.conf.ext
# Set up Dovecot config files
echo "!include_try /usr/share/dovecot/protocols.d/*.protocol
protocols = imap pop3 lmtp
dict {
}
!include conf.d/*.conf
!include_try local.conf" > /etc/dovecot/dovecot.conf
echo "mail_location = maildir:/var/mail/vhosts/%d/%n
mail_privileged_group = mail" > /etc/dovecot/conf.d/10-mail.conf
echo "auth_mechanisms = plain login
!include auth-sql.conf.ext" > /etc/dovecot/conf.d/10-auth.conf
echo "driver = mysql
connect = host=127.0.0.1 dbname=mailserver user=mailuser password=${mailuserpass}
default_pass_scheme = SHA512-CRYPT
password_query = SELECT email as user, password FROM virtual_users WHERE email='%u';" > /etc/dovecot/dovecot-sql.conf.ext
echo "service imap-login {
  inet_listener imap {
      port = 143
  }
  inet_listener imaps {
  }
}
service pop3-login {
  inet_listener pop3 {
      port = 110
  }
  inet_listener pop3s {
  }
}
service lmtp {
 unix_listener /var/spool/postfix/private/dovecot-lmtp {
   mode = 0600
   user = postfix
   group = postfix
  }
}
service imap {
}

service pop3 {
}
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
  unix_listener auth-userdb {
    mode = 0600
    user = vmail
    #group = vmail
  }
  user = dovecot
}
service auth-worker {
  user = vmail
}
service dict {
  unix_listener dict {
  }
}" > /etc/dovecot/conf.d/10-master.conf
echo "ssl_cert = </etc/ssl/certs/dovecot.pem
ssl_key = </etc/ssl/private/dovecot.pem" > /etc/dovecot/conf.d/10-ssl.conf

# Dovecot file structure
mkdir -p /var/mail/vhosts/
groupadd -g 5000 vmail
useradd -g vmail -u 5000 vmail -d /var/mail
chown -R vmail:vmail /var/mail
chown -R vmail:dovecot /etc/dovecot
chmod -R o-rwx /etc/dovecot


cd ~/neon-install/
status "Base Config: 12 / 13"

############################################################
# Begin Roundcube Configuration
############################################################

# Get Roundcube
wget -P /var/neon http://sourceforge.net/projects/roundcubemail/files/roundcubemail/0.9.2/roundcubemail-0.9.2.tar.gz/download
tar -C /var/neon -zxvf /var/neon/download
mv /var/neon/roundcubemail-0.9.2 /var/neon/roundcube
rm -f /var/neon/download

# Configure Nginx & PHP
echo "server {
        listen 2027;
    ssl    on;
    ssl_certificate  /usr/ssl/neon.crt;
    ssl_certificate_key  /usr/ssl/neon.key;
        server_name    www.neonserver.com;
        error_log /var/neon/data/nginx.error.log;

        error_page 497 https://$host:$server_port$request_uri;

        root /var/neon/roundcube;
        index index.php;

      location /var/neon/roundcube {
        autoindex off;
      }

      location /var/neon/roundcube/config {
        deny all;
      }

      location /var/neon/roundcube/temp {
        deny all;
      }

      location /var/neon/roundcube/logs {
        deny all;
      }

        location ~\.php$ {
                include fastcgi_params;
                fastcgi_intercept_errors off;
                fastcgi_pass 127.0.0.1:9000;
        }
}" > /etc/nginx/sites-enabled/roundcube.conf
echo "date.timezone = GMT" >> /etc/php5/fpm/php.ini # Might want to change this

# MySQL
roundcubepass=`< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-32};`
mysql -p${mysqlpassword} -e "CREATE DATABASE roundcube;"
mysql -p${mysqlpassword} -e "GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'localhost' IDENTIFIED BY \"${roundcubepass}\";"
mysql -p${mysqlpassword} -e "FLUSH PRIVILEGES;"
mysql -p${mysqlpassword} 'roundcube' < /var/neon/roundcube/SQL/mysql.initial.sql

# Roundcube config
cp /var/neon/roundcube/config/main.inc.php.dist /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['default_host'\] =\).*$|\1 \'localhost\';|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['smtp_server'\] =\).*$|\1 \'localhost\';|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['smtp_user'\] =\).*$|\1 \'%u\';|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['smtp_pass'\] =\).*$|\1 \'%p\';|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['quota_zero_as_unlimited'\] =\).*$|\1 true;|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['preview_pane'\] =\).*$|\1 true;|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['read_when_deleted'\] =\).*$|\1 false;|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['check_all_folders'\] =\).*$|\1 true;|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['display_next'\] =\).*$|\1 true;|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['top_posting'\] =\).*$|\1 true;|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['sig_above'\] =\).*$|\1 true;|" /var/neon/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['login_lc'\] =\).*$|\1 2;|" /var/neon/roundcube/config/main.inc.php
cp /var/neon/roundcube/config/db.inc.php.dist /var/neon/roundcube/config/db.inc.php
sed -i "s|^\(\$rcmail_config\['db_dsnw'\] =\).*$|\1 \'mysqli://roundcube:${roundcubepass}@localhost/roundcube\';|" /var/neon/roundcube/config/db.inc.php
rm -rf /var/neon/roundcube/installer


cd ~/neon-install/
status "Base Config: 13 / 13"

############################################################
# Begin Clean Up
############################################################

status "Finishing and cleaning up..."
aptitude -y purge ~i~napache
/etc/init.d/nginx start
/etc/init.d/pdns start
/etc/init.d/php5-fpm start
/etc/init.d/postfix restart
/etc/init.d/dovecot restart
cd /var/neon/neonpanel/
php init.php
rm -rf init.php
cd ~/neon-install/
(crontab -l 2>/dev/null; echo "* * * * * sh /var/neon/data/scripts/stats.sh") | crontab -
ipaddress=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | grep -v '127.0.0.2' | cut -d: -f2 | awk '{ print $1}'`;
mysql -u root --password="$mysqlpassword" --execute="UPDATE panel.settings SET setting_value='$ipaddress' WHERE id='5';"
wget --delete-after http://www.neoncp.com/installer/report.php?ip=$ipaddress

status "=========NEON_INSTALL_COMPLETE========"
status "Mysql Root Password: $mysqlpassword"
status "You can now login at https://$ipaddress:2026"
status "Username: root"
status "Password: your_root_password"
status "====================================="
status "It is reccomended you download the"
status "log ~/neon-install/neon-install.log"
status "and then delete it from your system."