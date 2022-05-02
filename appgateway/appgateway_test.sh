#!/bin/bash

APPGW_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${APPGW_DIR}/../utils/utils.sh
source ${APPGW_DIR}/../utils/test_config.properties

function verifyAppGatewayHTTPS()
{
    echo "verifying App Gateway HTTPS URL..."

    response=$(curl --insecure --write-out '%{http_code}' --silent --output /dev/null https://wlsgw2290a1-guru-cluster-test-wlsd.eastus.cloudapp.azure.com/shoppingcart/)

    if [ "$response" == "200" ];
    then
       echo "SUCCESS: AppGateway verification is successful."
       notifyPass
    else
       echo "FAIL: AppGateway verification failed."
       notifyFail
    fi
}

function verifyAppGatewayHTTP()
{
    echo "verifying App Gateway HTTP URL..."

    response=$(curl --insecure --write-out '%{http_code}' --silent --output /dev/null http://wlsgw2290a1-guru-cluster-test-wlsd.eastus.cloudapp.azure.com/shoppingcart/)

    if [ "$response" == "200" ];
    then
       echo "SUCCESS: AppGateway verification is successful."
       notifyPass
    else
       echo "FAIL: AppGateway verification failed."
       notifyFail
    fi
}


#main

get_param "$@"

verifyAppGatewayHTTPS

verifyAppGatewayHTTP

printTestSummary

