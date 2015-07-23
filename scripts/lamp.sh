#!/bin/bash

echo "Applying nodejs signing key..."
apt-key adv --quiet --keyserver hkp://keyserver.ubuntu.com:80 --recv-key C7917B12 2>&1 | grep "gpg:"
apt-key export C7917B12 | apt-key add -

echo "Running apt-get update..."
apt-get update --assume-yes

echo "Installing apt-get packages..."
apt-get -y install apache2 mysql-server mysql-client php5-mysql
apt-get -y install phpmyadmin
apt-get -y install php5 libapache2-mod-php5 php5-mcrypt php5-curl php5-common php5-gd php5-dev php5-memcache php-pear

apt-get -y install memcached imagemagick git-core zip unzip ngrep curl make vim colordiff postfix
apt-get -y install ntp gettext dos2unix g++ nodejs


apt-get clean

# npm
#
# Make sure we have the latest npm version and the update checker module
npm install -g npm
npm install -g npm-check-updates

# xdebug
#
# XDebug 2.2.3 is provided with the Ubuntu install by default. The PECL
# installation allows us to use a later version. Not specifying a version
# will load the latest stable.
pecl install xdebug


if [[ ! -n "$(composer --version --no-ansi | grep 'Composer version')" ]]; then
	echo "Installing Composer..."
	curl -sS https://getcomposer.org/installer | php
	chmod +x composer.phar
	mv composer.phar /usr/local/bin/composer
fi

# Update both Composer and any global packages. Updates to Composer are direct from
# the master branch on its GitHub repository.
if [[ -n "$(composer --version --no-ansi | grep 'Composer version')" ]]; then
	echo "Updating Composer..."
	COMPOSER_HOME=/usr/local/src/composer composer self-update
	COMPOSER_HOME=/usr/local/src/composer composer -q global require --no-update phpunit/phpunit:4.3.*
	COMPOSER_HOME=/usr/local/src/composer composer -q global require --no-update phpunit/php-invoker:1.1.*
	COMPOSER_HOME=/usr/local/src/composer composer -q global require --no-update mockery/mockery:0.9.*
	COMPOSER_HOME=/usr/local/src/composer composer -q global require --no-update d11wtq/boris:v1.0.8
	COMPOSER_HOME=/usr/local/src/composer composer -q global config bin-dir /usr/local/bin
	COMPOSER_HOME=/usr/local/src/composer composer global update
fi

# Grunt
#
# Install or Update Grunt based on current state.  Updates are direct
# from NPM
if [[ "$(grunt --version)" ]]; then
	echo "Updating Grunt CLI"
	npm update -g grunt-cli &>/dev/null
	npm update -g grunt-sass &>/dev/null
	npm update -g grunt-cssjanus &>/dev/null
	npm update -g grunt-rtlcss &>/dev/null
else
	echo "Installing Grunt CLI"
	npm install -g grunt-cli &>/dev/null
	npm install -g grunt-sass &>/dev/null
	npm install -g grunt-cssjanus &>/dev/null
	npm install -g grunt-rtlcss &>/dev/null
fi

#WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp


#Restart Service
service apache2 restart
service mysql restart
service memcached restart
php5enmod xdebug
php5enmod mcrypt