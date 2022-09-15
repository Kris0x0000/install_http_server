#!/bin/bash

#### config ####
WAN_IP='xx.xxx.xxx.xx'
DATA_PATH='/mnt/data'
CONF_PATH="`pwd`/etc"
MARIADB_VER='10.5'
PHP_VER='7.3'
PHPMYADMIN_VER='5.1.0'
FTP_PASSWORD='xxxxxxxxxxxxx' 
SQL_USER='sqladmin'
SQL_PASSWORD="xxxxxxxxxxxxx"

#### end of config ####

#### info (DO NOT EDIT) ####
# ftp login: dev

#### end of info ####

COLOR='\e[1;35m%-6s\e[m'

# setting timezone
printf $COLOR "setting timezone"
echo
timedatectl set-timezone Europe/Warsaw 1> /dev/null

# owning conf files
printf $COLOR "owning conf files"
echo
chown -R root:root $CONF_PATH 1> /dev/null

# disabling SeLinux
printf $COLOR "disabling SeLinux"
echo
setenforce 0 1> /dev/null

#installing repos
printf $COLOR "installing repos"
echo
dnf -y install epel-release 1> /dev/null
cp $CONF_PATH/yum.repos.d/MariaDB.repo /etc/yum.repos.d/ 1> /dev/null
sed -i "s|baseurl = http://yum.mariadb.org/[0-9][0-9]\.[0-9]|baseurl = http://yum.mariadb.org/$MARIADB_VER|g" /etc/yum.repos.d/MariaDB.repo 1> /dev/null


#enabling versions
printf $COLOR "enabling versions"
echo
dnf -y module enable php:$PHP_VER 1> /dev/null

#installing software
printf $COLOR "installing software "
echo
dnf -y install httpd vsftpd MariaDB-server fail2ban vim htop mc rsync \
php php-cli php-common php-fpm php-gd php-json php-mbstring php-mysqlnd \
php-opcache php-pdo php-pecl-zip php-xml php-soap php-pecl-imagick unzip wget sysstat goaccess 1> /dev/null

# setting directory
printf $COLOR "setting data directory"
echo
mkdir -p $DATA_PATH/www/aplikacja 1> /dev/null
mkdir -p $DATA_PATH/www/stats 1> /dev/null

# setting user and directory permissions
printf $COLOR "setting users and directory permissions"
echo
useradd -M -N -p "$FTP_PASSWORD" dev -G ftp-users -s /bin/nologin 1> /dev/null 
chown -R apache:ftp-users $DATA_PATH/www/ 1> /dev/null
chmod -R 775 $DATA_PATH/www/ 1> /dev/null
mkdir $DATA_PATH/php_sessions 1> /dev/null
chown apache:apache $DATA_PATH/php_sessions 1> /dev/null

# copying conf files
printf $COLOR "copying conf files"
echo
yes | cp -fR $CONF_PATH/* /etc/ 1> /dev/null

# modyfing conf files
printf $COLOR "modyfing conf files"
echo
sed -i "s|pasv_address=[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}|pasv_address=$WAN_IP|g" /etc/vsftpd/vsftpd.conf 1> /dev/null

# moving database 
printf $COLOR "moving database"
echo
mv /var/lib/mysql $DATA_PATH/ 1> /dev/null

# copying index.php
printf $COLOR "copying index.php"
echo
cp $CONF_PATH/other/index.php $DATA_PATH/www/aplikacja/ 1> /dev/null

# Opening ports on firewall
printf $COLOR "opening ports"
echo
firewall-cmd --zone=public --permanent --add-service=https 1> /dev/null
firewall-cmd --zone=public --permanent --add-service=http 1> /dev/null
firewall-cmd --zone=public --permanent --add-service=ftp 1> /dev/null
firewall-cmd --zone=public --permanent --add-port=88/tcp 1> /dev/null
firewall-cmd --zone=public --permanent --add-port=40000-40200/tcp 1> /dev/null
firewall-cmd --set-default-zone=public
firewall-cmd --reload

# starting services
printf $COLOR "starting services"
echo
systemctl start mysql 1> /dev/null
systemctl start httpd 1> /dev/null
systemctl start php-fpm 1> /dev/null
systemctl start vsftpd 1> /dev/null
systemctl start fail2ban 1> /dev/null

# enabling services
printf $COLOR "enabling services"
echo
systemctl enable mysql 1> /dev/null
systemctl enable httpd 1> /dev/null
systemctl enable php-fpm 1> /dev/null
systemctl enable vsftpd 1> /dev/null
systemctl enable fail2ban 1> /dev/null


# setting ftp password
printf $COLOR "setting ftp password"
echo
echo $FTP_PASSWORD | passwd dev --stdin 1> /dev/null

# setting ftp permissions
printf $COLOR "setting ftp permissions"
echo
setfacl -dm u:apache:rwx $DATA_PATH/www/aplikacja/
setfacl -m u:apache:rwx $DATA_PATH/www/aplikacja/
setfacl -dm g:ftp-users:rwx $DATA_PATH/www/aplikacja/
setfacl -m g:ftp-users:rwx $DATA_PATH/www/aplikacja/


#instaling composer and php libs
printf $COLOR "instaling composer and php libs"
echo
wget -P /tmp https://getcomposer.org/installer 1> /dev/null
chmod +x /tmp/installer 1> /dev/null
php /tmp/installer --filename=composer --install-dir=/bin 1> /dev/null
cd $DATA_PATH/www/aplikacja/ 1> /dev/null
composer require mpdf/mpdf 1> /dev/null
composer require ezyang/htmlpurifier 1> /dev/null
composer require phpmailer/phpmailer 1> /dev/null
composer require sendinblue/api-v3-sdk 1> /dev/null
composer require phpoffice/phpspreadsheet 1> /dev/null
composer require org_heigl/ghostscript 1> /dev/null

# php browscap
printf $COLOR "instaling php browscap"
echo
mkdir /etc/php_extra 1> /dev/null
chown apache:apache /etc/php_extra 1> /dev/null
chmod 2770 /etc/php_extra 1> /dev/null
wget -O /etc/php_extra/browscap.ini https://browscap.org/stream?q=BrowsCapINI 1> /dev/null

# setting sql account for phpmyadmin
printf $COLOR "setting sql account for phpmyadmin"
echo
mysql -u root -e "CREATE USER $SQL_USER@localhost IDENTIFIED BY '$SQL_PASSWORD';GRANT ALL PRIVILEGES ON *.* TO $SQL_USER@localhost WITH GRANT OPTION;FLUSH PRIVILEGES;"

# installing phpmyadmin
printf $COLOR "instaling phpmyadmin"
echo
wget -P /tmp "https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VER/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz" 1> /dev/null
tar -xzf /tmp/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz -C $DATA_PATH/www/ 1> /dev/null
mv $DATA_PATH/www/phpMyAdmin-$PHPMYADMIN_VER-all-languages $DATA_PATH/www/phpmyadmin 1> /dev/null
chown -R apache:apache $DATA_PATH/www/phpmyadmin 1> /dev/null
cp $DATA_PATH/www/phpmyadmin/config.sample.inc.php $DATA_PATH/www/phpmyadmin/config.inc.php
sed -i "s|localhost|127.0.0.1|g" $DATA_PATH/www/phpmyadmin/config.inc.php
HASH=`head -30 /dev/urandom | md5sum | cut -d " " -f 1`
sed -i "s|\[\x27blowfish_secret\x27\] \= \x27\x27|\[\x27blowfish_secret\x27\] \= \x27$HASH\x27|g" $DATA_PATH/www/phpmyadmin/config.inc.php
systemctl restart httpd 1> /dev/null


# setting crontab jobs
printf $COLOR "setting crontab jobs"
echo
(crontab -l ; echo "*/15 * * * * /bin/find $DATA_PATH/php_sessions -maxdepth 1 -name "sess_* " -mmin +720 -type f -delete >/dev/null 2>&1") | crontab
(crontab -l ; echo "5 23 1 * * wget -O /etc/php_extra/browscap.ini https://browscap.org/stream?q=BrowsCapINI >/dev/null 2>&1") | crontab
(crontab -l ; echo "0 1 * * * goaccess /var/log/httpd/access_log -a -o $DATA_PATH/www/stats/index.html --log-format=COMBINED >/dev/null 2>&1") | crontab

printf $COLOR "Done. Please reboot the system."
