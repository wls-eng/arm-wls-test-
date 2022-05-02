#!/bin/bash

SSL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${SSL_DIR}/../utils/utils.sh
source ${SSL_DIR}/../utils/test_config.properties

output=$(curl -L --insecure --write-out '%{http_code}' --silent --output /dev/null https://adminVM:7002/console)

if [ "$output" == "200" ];
then
  echo "Admin console accessible on SSL Port"
  notifyPass
else
  echo "Admin console not accessible on SSL Port"
  notifyFail
fi

openssl s_client -servername adminVM -showcerts -connect adminVM:7002 | grep Subject

printTestSummary


