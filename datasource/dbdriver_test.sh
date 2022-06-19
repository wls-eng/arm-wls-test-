#!/bin/bash

DATASOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${DATASOURCE_DIR}/../utils/utils.sh
source ${DATASOURCE_DIR}/../utils/test_config.properties

function testJDBCDriverInfoAppDeployment()
{
    mkdir -p /tmp/deploy
    cp ${JDBC_DRIVERINFO_APP_PATH} /tmp/deploy/
    chown -R oracle:oracle /tmp/deploy

    startTest

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state)
    adminServerName=$(echo "$output" | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]| select(.name| index("admin"))|.name')
    
    print "adminServerName $adminServerName"
    retcode=$(curl -s \
            --user ${WLS_USERNAME}:${WLS_PASSWORD} \
            -H X-Requested-By:MyClient \
            -H Accept:application/json \
            -H Content-Type:application/json \
            -d "{
                name: '${JDBC_DRIVERINFO_APP_NAME}',
                deploymentPath: '/tmp/deploy/${JDBC_DRIVERINFO_APP}',
                targets:    [ '${adminServerName}' ]
            }" \
            -X POST ${HTTP_ADMIN_URL}/management/wls/latest/deployments/application)
 
    print "$retcode"

    deploymentStatus=$(echo "$retcode" | jq -r '.messages[]|.severity')

    if [ "${deploymentStatus}" != "SUCCESS" ];
    then
        echo "FAILURE: App Deployment Failed. Deployment Status: ${deploymentStatus}"
        notifyFail
    else
        echo "SUCCESS: App Deployed Successfully. Deployment Status: ${deploymentStatus}"
        notifyPass
    fi
    rm -rf /tmp/deploy

    print "Wait for 15 seconds for the deployed Apps to become available..."
    sleep 15s

    endTest
}

function verifyJDBCDriver()
{
    print "verifying JDBC Driver..."

    output=$(curl -s \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -X GET ${HTTP_ADMIN_URL}/jdbcDriverInfo/JDBCDriverInfoServlet?dsname=${DS_JNDI})

    print "$output"

    result=$(echo "$output" | jq -r '.result'| grep -i SUCCESS)
    
    if [ "$result" != "SUCCESS" ];
    then
        echo "FAILURE: JDBC Driver verification is not successful."
        notifyFail
    else
        echo "SUCCESS: JDBC Driver verification is successful."
        notifyPass
    fi
}


#main

get_param "$@"

validate_input

if [ -z "$DS_JNDI" ];
then
  echo "FAILURE: Datasource JNDI name not provided "
  notifyFail
else
  testJDBCDriverInfoAppDeployment
  verifyJDBCDriver
fi

printTestSummary
