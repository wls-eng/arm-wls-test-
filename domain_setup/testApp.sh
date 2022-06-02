#!/bin/bash

function checkURL()
{
  url="$1"
  response=$(curl -L --insecure --write-out '%{http_code}' --silent --output /dev/null $url)
  if [ "$response" == "200" ];
  then
    echo "URL $url -- pass"
  else
    echo "URL $url -- fail"
 fi
}

#main

checkURL http://$HOSTNAME:7001/console
checkURL https://$HOSTNAME:7002/console
checkURL http://$HOSTNAME:7003/replicationwebapp/FirstServlet
checkURL http://$HOSTNAME:7004/replicationwebapp/FirstServlet

for run in {1..10}; do
  curl -L -s --insecure http://$HOSTNAME:7003/replicationwebapp/FirstServlet
  sleep 1s
done


for run in {1..10}; do
  curl -L -s --insecure http://$HOSTNAME:7004/replicationwebapp/FirstServlet
  sleep 1s
done

