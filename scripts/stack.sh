#!/bin/bash

# By storing the date now, we can calculate the duration of provisioning at the
# end of this script.
start_seconds="$(date +%s)"

#set hostname
NEW_HOSTNAME="devstack"
echo $NEW_HOSTNAME > /proc/sys/kernel/hostname
sed -i 's/127.0.1.1.*/127.0.1.1\t'"$NEW_HOSTNAME"'/g' /etc/hosts
echo $NEW_HOSTNAME > /etc/hostname
service hostname start

# Network Detection
#
# Make an HTTP request to google.com to determine if outside access is available
# to us. If 3 attempts with a timeout of 5 seconds are not successful, then we'll
# skip a few things further in provisioning rather than create a bunch of errors.
if [[ "$(wget --tries=3 --timeout=5 --spider http://google.com 2>&1 | grep 'connected')" ]]; then
	echo "Network connection detected..."
	ping_result="Connected"
else
	echo "Network connection not detected. Unable to reach google.com..."
	ping_result="Not Connected"
fi

# PACKAGE INSTALLATION
#
# Build a bash array to pass all of the packages we want to install to a single
# apt-get command. This avoids doing all the leg work each time a package is
# set to install. It also allows us to easily comment out or add single
# packages. We set the array as empty to begin with so that we can append
# individual packages to it as required.
apt_package_install_list=()

# Start with a bash array containing all packages we want to install in the
# virtual machine. We'll then loop through each of these and check individual
# status before adding them to the apt_package_install_list array.
apt_package_check_list=(

	# apache2 is installed as the default web server
	apache2

	# PHP5
	#
	# Our base packages for php5. As long as php5-fpm and php5-cli are
	# installed, there is no need to install the general php5 package, which
	# can sometimes install apache as a requirement.
	php5
	php5-cli

	# Common and dev packages for php
	php5-common
	php5-dev

	# Extra PHP modules that we find useful
	php5-memcache
	php5-imagick
	php5-mcrypt
	php5-mysql
	php5-imap
	php5-curl
	php-pear
	php5-gd

	# memcached is made available for object caching
	memcached

	# mysql is the default database
	mysql-server
	mysql-client

	#phpmyadmin
	phpmyadmin

	# other packages that come in handy
	imagemagick
	subversion
	git-core
	zip
	unzip
	ngrep
	curl
	make
	vim
	colordiff
	postfix

	# ntp service to keep clock current
	ntp

	# Req'd for i18n tools
	gettext

	# dos2unix
	# Allows conversion of DOS style line endings to something we'll have less
	# trouble with in Linux.
	dos2unix

	# nodejs for use by grunt
	g++
	nodejs
	npm
	ruby-dev
)

echo "Check for apt packages to install..."

# Loop through each of our packages that should be installed on the system. If
# not yet installed, it should be added to the array of packages to install.
for pkg in "${apt_package_check_list[@]}"; do
	package_version="$(dpkg -s $pkg 2>&1 | grep 'Version:' | cut -d " " -f 2)"
	if [[ -n "${package_version}" ]]; then
		space_count="$(expr 20 - "${#pkg}")" #11
		pack_space_count="$(expr 30 - "${#package_version}")"
		real_space="$(expr ${space_count} + ${pack_space_count} + ${#package_version})"
		printf " * $pkg %${real_space}.${#package_version}s ${package_version}\n"
	else
		echo " *" $pkg [not installed]
		apt_package_install_list+=($pkg)
	fi
done

# MySQL
#
# Use debconf-set-selections to specify the default password for the root MySQL
# account. This runs on every provision, even if MySQL has been installed. If
# MySQL is already installed, it will not affect anything.
echo mysql-server mysql-server/root_password password root | debconf-set-selections
echo mysql-server mysql-server/root_password_again password root | debconf-set-selections

#PHPMyAdmin
echo phpmyadmin phpmyadmin/dbconfig-install boolean false | debconf-set-selections
echo phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2 | debconf-set-selections

echo phpmyadmin phpmyadmin/app-password-confirm password root | debconf-set-selections
echo phpmyadmin phpmyadmin/mysql/admin-pass password root | debconf-set-selections
echo phpmyadmin phpmyadmin/password-confirm password root | debconf-set-selections
echo phpmyadmin phpmyadmin/setup-password password root | debconf-set-selections
echo phpmyadmin phpmyadmin/database-type select mysql | debconf-set-selections
echo phpmyadmin phpmyadmin/mysql/app-pass password root | debconf-set-selections

echo dbconfig-common dbconfig-common/mysql/app-pass password root | debconf-set-selections
echo dbconfig-common dbconfig-common/mysql/app-pass password | debconf-set-selections
echo dbconfig-common dbconfig-common/password-confirm password root | debconf-set-selections
echo dbconfig-common dbconfig-common/app-password-confirm password root | debconf-set-selections
echo dbconfig-common dbconfig-common/app-password-confirm password root | debconf-set-selections
echo dbconfig-common dbconfig-common/password-confirm password root | debconf-set-selections

# Postfix
#
# Use debconf-set-selections to specify the selections in the postfix setup. Set
# up as an 'Internet Site' with the host name 'vvv'. Note that if your current
# Internet connection does not allow communication over port 25, you will not be
# able to send mail, even with postfix installed.
echo postfix postfix/main_mailer_type select Internet Site | debconf-set-selections
echo postfix postfix/mailname string devstack | debconf-set-selections

# Disable ipv6 as some ISPs/mail servers have problems with it
echo "inet_protocols = ipv4" >> /etc/postfix/main.cf

if [[ $ping_result == "Connected" ]]; then
	# If there are any packages to be installed in the apt_package_list array,
	# then we'll run `apt-get update` and then `apt-get install` to proceed.
	if [[ ${#apt_package_install_list[@]} = 0 ]]; then
		echo -e "No apt packages to install.\n"
	else
		# Before running `apt-get update`, we should add the public keys for
		# the packages that we are installing from non standard sources via
		# our appended apt source.list

		# Apply the nodejs assigning key
		echo "Applying nodejs signing key..."
		apt-key adv --quiet --keyserver hkp://keyserver.ubuntu.com:80 --recv-key C7917B12 2>&1 | grep "gpg:"
		apt-key export C7917B12 | apt-key add -

		# update all of the package references before installing anything
		echo "Running apt-get update..."
		apt-get update --assume-yes

		# install required packages
		echo "Installing apt-get packages..."
		apt-get install --assume-yes ${apt_package_install_list[@]}

		# Clean up apt caches
		apt-get clean
	fi

	# npm
	#
	# Make sure we have the latest npm version and the update checker module
	npm install -g npm
	npm install -g npm-check-updates
	ln -s /usr/bin/nodejs /usr/bin/node

	# xdebug
	#
	# XDebug 2.2.3 is provided with the Ubuntu install by default. The PECL
	# installation allows us to use a later version. Not specifying a version
	# will load the latest stable.
	pecl install xdebug

	# ack-grep
	#
	# Install ack-rep directory from the version hosted at beyondgrep.com as the
	# PPAs for Ubuntu Precise are not available yet.
	if [[ -f /usr/bin/ack ]]; then
		echo "ack-grep already installed"
	else
		echo "Installing ack-grep as ack"
		curl -s http://beyondgrep.com/ack-2.04-single-file > /usr/bin/ack && chmod +x /usr/bin/ack
	fi

	# COMPOSER
	#
	# Install Composer if it is not yet available.
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
	else
		echo "Installing Grunt CLI"
		npm install -g grunt-cli &>/dev/null
		npm install -g grunt-sass &>/dev/null
		npm install -g grunt-cssjanus &>/dev/null
	fi

	#WP-CLI
	curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	chmod +x wp-cli.phar
	sudo mv wp-cli.phar /usr/local/bin/wp

	# Ruby module
	gem update --system
	gem install sass
	gem install compass

	#Add virtual host
	cd /usr/local/bin
	wget -O virtualhost https://raw.githubusercontent.com/RoverWire/virtualhost/master/virtualhost.sh
	chmod +x virtualhost
	virtualhost create local.dev devstack

else
	echo -e "\nNo network connection available, skipping package installation"
fi

# Add the vagrant user to the www-data group so that it has better access
# to PHP and Apache related files.
usermod -a -G www-data vagrant

php5enmod xdebug
php5enmod mcrypt
a2enmod rewrite

#Restart Service
service apache2 restart
service mysql restart
service memcached restart

end_seconds="$(date +%s)"
echo "-----------------------------"
echo "Provisioning complete in "$(expr $end_seconds - $start_seconds)" seconds"
if [[ $ping_result == "Connected" ]]; then
	echo "External network connection established, packages up to date."
else
	echo "No external network available. Package installation and maintenance skipped."
fi