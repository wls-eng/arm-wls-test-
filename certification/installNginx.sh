#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

/usr/sbin/nginx -V &>/dev/null
result=$?

if [ "$result" != "0" ];
then
  echo "nginx is not installed. Installing..."
  #Install EPEl for installing sshpass

  if [ -f /etc/yum.repos.d/nginx.repo ]
  then
    rm -f /etc/yum.repos.d/nginx.repo
  fi

  touch /etc/yum.repos.d/nginx.repo

cat >/etc/yum.repos.d/nginx.repo <<EOL
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/rhel/7/\$basearch/
gpgcheck=0
enabled=1
EOL

  yum install -y nginx
  systemctl status nginx

  if [ $? != 0 ];
  then
      systemctl start nginx.service
      sleep 10s
      systemctl status nginx

      if [ $? != 0 ];
      then
          echo "nginx not installed. Exiting..."
          exit 1
      else
          echo "nginx has been installed succesfully... proceeding with next steps..."
      fi
   fi
else
  echo "nginx already installed."
fi

#run below commands to provide permission to nginx to perform reverse proxying
setsebool -P httpd_can_network_connect 1
setsebool -P httpd_can_network_relay 1

cp ${SCRIPT_DIR}/config/weblogic.conf /etc/nginx/conf.d/
/usr/sbin/nginx -t
systemctl restart nginx.service

if [ $? == 0 ];
then
  echo "Nginx setup completed successfully."
  exit 0
else
  echo "Failure in configuring Nginx as load balancer"
  exit 1
fi
