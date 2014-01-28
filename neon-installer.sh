#!/bin/bash

mkdir ~/neon-install/
cd ~/neon-install/
touch ~/neon-install/install.log
exec 3>&1 > ~/neon-install/install.log 2>&1

############################################################
# Functions
############################################################

function install {
	DEBIAN_FRONTEND=noninteractive apt-get -q -y install "$1"
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

function check_sanity {
	# Do some sanity checking.
	if [ $(/usr/bin/id -u) != "0" ]
	then
		die 'Neon must be installed as root. Please log in as root and try again.'
	fi
}

function die {
	echo "ERROR: $1" > /dev/null 1>&2
	exit 1
}

function status {
	echo $1;
	echo $1 >&3
}

check_sanity


status "====================================="
status "     Welcome to Neon Installation"
status "====================================="
status "Neon will remove any existing apache,"
status "nginx, mysql or php services you have"
status "installed upon this server. It will"
status "also delete all custom config files"
status "that you may have."
status " "
status "It is recommended that you run this"
status "installer in a screen."
status " "
status "This script will begin installing"
status "Neon in 10 seconds. If you wish to"
status "cancel the install press CTRL + C"
sleep 10
status " "
status "Neon is now being installed."
status "Beginning cleanup..."

remove="apache2 apache* apache2* apache2-utils mysql* php* nginx lighttpd httpd* php5-fpm vsftpd proftpd exim qmail postfix sendmail"

pkill apache
pkill apache2
aptitude -y purge ~i~napache
apt-get --purge -y autoremove apache*
apt-get remove apache2-utils
for program in $remove
do
	remove $program
	x=$(($x + 1));
	status "Clean Up: $x / 16"
done
apt-get autoremove

update-rc.d -f apache2 remove
update-rc.d -f apache remove
update-rc.d -f nginx remove
update-rc.d -f httpd remove
update-rc.d -f lighttpd remove

status "Clean Up Completed."
status "Starting installation please wait..."

apt-get update
y=$(($y + 1));
status "Install: $y / 7"

install="nginx php5 php5-fpm php-curl git-core"

for program in $install
do
	install $program
	y=$(($y + 1));
	status "Install: $y / 7"
done

mkdir /var/neon/
git clone -b develop-develop https://github.com/BlueVM/Neon.git /var/neon/
status "Install: $y / 7"

status "Installation completed."
status "Starting configuration please wait..."

cp /var/neon/neonpanel/includes/configs/php.conf /etc/php5/fpm/pool.d/www.conf
cp /var/neon/data/config.example /var/neon/data/config.json
status "Config: 1 / 7"

mkdir /usr/ssl
cd /usr/ssl
openssl genrsa -out neon.key 1024
openssl rsa -in neon.key -out neon.pem
openssl req -new -key neon.pem -subj "/C=US/ST=Oregon/L=Portland/O=IT/CN=www.neonpanel.com" -out neon.csr
openssl x509 -req -days 365 -in neon.csr -signkey neon.pem -out neon.crt
status "Config: 2 / 7"

cd ~/neon-install/
rm -rf /etc/nginx/sites-enabled/* 
cp /var/neon/neonpanel/includes/configs/nginx.neon.conf /etc/nginx/sites-enabled/nginx.neon.conf
status "Config: 3 / 7"

rm -rf /etc/php5/fpm/php.ini
cp /var/neon/neonpanel/includes/configs/php.ini /etc/php5/fpm/php.ini
status "Config: 4 / 7"

cd /var/neon/
chown -R www-data *
chmod -R 700 *
status "Config: 5 / 7"

service nginx restart
service php5-fpm restart
(crontab -l 2>/dev/null; echo "* * * * * sh /var/neon/neonpanel/cron.php") | crontab -
ipaddress=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | grep -v '127.0.0.2' | cut -d: -f2 | awk '{ print $1}'`;
status "Config: 6 / 7"

touch /var/neon/data/log.txt
mkdir /var/neon/neonpanel/uploads
mkdir /var/neon/neonpanel/downloads
mkdir /home/root/
pkill apache
pkill apache2
service nginx restart
service php5-fpm restart
status "Config: 7 / 7"

status "=========NEON_INSTALL_COMPLETE========"
status "You can now login at https://$ipaddress:2026"
status "Username: root"
status "Password: your root password"
status "====================================="
status "It is recommended you download the"
status "log ~/neon-install/neon-install.log"
status "and then delete it from your system."