#!/bin/bash

DATASOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${DATASOURCE_DIR}/../utils/utils.sh
source ${DATASOURCE_DIR}/../utils/test_config.properties

function verifyJDBCDataSource()
{
    echo "verifying JDBC Datasource..."

    output=$(curl -s -v \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/tenant-monitoring/datasources)

    echo $output | jq -r '.body.items[].instances[].state'| grep -i Running
    
    if [ "$?" != "0" ];
    then
        echo "FAILURE: Database connection is not successful. Please check Datasource configuration and try again."
        notifyFail
    else
        echo "SUCCESS: JDBC Datasource connection is successful."
        notifyPass
    fi
}


#main

get_param "$@"

validate_input

verifyJDBCDataSource

printTestSummary
