#!/bin/bash
#
# Setup the the box. This runs as root

apt-get -y update

apt-get -y upgrade

apt-get -y install curl

# You can install anything you need here.

# Provides Nginx mainline
deb http://nginx.org/packages/mainline/ubuntu/ trusty nginx
deb-src http://nginx.org/packages/mainline/ubuntu/ trusty nginx

# Provides Node.js
deb http://ppa.launchpad.net/chris-lea/node.js/ubuntu trusty main
deb-src http://ppa.launchpad.net/chris-lea/node.js/ubuntu trusty main
