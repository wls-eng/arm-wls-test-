#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $CURR_DIR/../utils/utils.sh

function isServerRunning()
{
    serverName="$1"
    serverStatus="$2"

    print "serverName: $serverName"
    print "serverStatus: $serverStatus"

    if [ -z "$serverStatus" ];
    then
        echo "FAILURE: Invalid Server Status for Server $serverName"
        notifyFail
    fi

    if [ "$serverStatus" != "RUNNING" ];
    then
        echo "FAILURE: Server $serverName not running as expected."
        notifyFail
    else
        echo "SUCCESS: Server $serverName running as expected."
        notifyPass
    fi
}

function testWLSDomainPath()
{
    startTest

    print "DOMAIN_DIR: ${ADMIN_DOMAIN_DIR}"

    if [ ! -d "${ADMIN_DOMAIN_DIR}" ]; then
      echo "FAILURE: Weblogic Server Domain directory not setup as per the expected directory structure: ${ADMIN_DOMAIN_DIR} "
      notifyFail
    else
      echo "SUCCESS: Weblogic Server Domain path verified successfully"
      notifyPass
    fi

    endTest
}


function testAdminConsoleHTTP()
{
    startTest

    retcode=$(curl -L -s -o /dev/null -w "%{http_code}" ${HTTP_CONSOLE_URL} )

    if [ "${retcode}" != "200" ];
    then
        echo "FAILURE: Admin Console is not accessible. Curl returned code ${retcode}"
        notifyFail
    else
        echo "SUCCESS: Admin Console is accessible. Curl returned code ${retcode}"
        notifyPass
    fi

    endTest
}

function testAdminConsoleHTTPS()
{
    startTest

    retcode=$(curl --no-keepalive --insecure -L -s -o /dev/null -w "%{http_code}" ${HTTPS_CONSOLE_URL})

    if [ "${retcode}" != "200" ];
    then
        echo "FAILURE: Admin Console is not accessible. Curl returned code ${retcode}"
        notifyFail
    else
        echo "SUCCESS: Admin Console is accessible. Curl returned code ${retcode}"
        notifyPass
    fi

    endTest
}

function testServerStatus()
{
    startTest

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state)

    adminServerStatus=$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name | test($ADMIN_NAME;"i")) | .state ')
    print "Admin Server Status: $adminServerStatus"

    isServerRunning "AdminServer" "$adminServerStatus"
    sleep 1s
    endTest
}

function testAppDeployment()
{

    mkdir -p /tmp/deploy
    cp ${SHOPPING_CART_APP_PATH} /tmp/deploy/
    chown -R oracle:oracle /tmp/deploy

    startTest

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state)

    adminServerName=$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name | test($ADMIN_NAME;"i")) | .name ')

    print "adminServerName $adminServerName"

    retcode=$(curl -s \
            --user ${WLS_USERNAME}:${WLS_PASSWORD} \
            -H X-Requested-By:MyClient \
            -H Accept:application/json \
            -H Content-Type:application/json \
            -d "{
                name: '${SHOPPING_CART_APP_NAME}',
                deploymentPath: '/tmp/deploy/${SHOPPING_DEPLOY_APP}',
                targets:    [ '${adminServerName}' ]
            }" \
            -X POST ${HTTP_ADMIN_URL}/management/wls/latest/deployments/application)

    print "$retcode"

    deploymentStatus="$(echo $retcode | jq -r '.messages[]|.severity')"

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

function testAppUnDeployment()
{

    startTest

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state)

    adminServerName=$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name | test($ADMIN_NAME;"i")) | .name ')

    print "adminServerName $adminServerName"

    retcode=$(curl -s \
            --user ${WLS_USERNAME}:${WLS_PASSWORD} \
            -H X-Requested-By:MyClient \
            -H Accept:application/json \
            -H Content-Type:application/json \
            -d "{
                targets:    [ '${adminServerName}' ],
                deploymentOptions: {}
            }" \
            -X POST ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/deploymentManager/appDeploymentRuntimes/${SHOPPING_CART_APP_NAME}/undeploy)

    print "$retcode"

    undeploymentStatus="$(echo $retcode | jq -r '.completed')"

    if [ "$undeploymentStatus" == "true" ];
    then
       echo "SUCCESS: Shopping cart Application undeployed successfully"
       notifyPass
    else
       echo "FAILURE: Shopping cart Application undeployment failed"
       notifyFail
    fi

endTest
}


function testDeployedAppHTTP()
{
    startTest

    retcode=$(curl -L -s -o /dev/null -w "%{http_code}" ${ADMIN_HTTP_SHOPPING_CART_APP_URL} )

    if [ "${retcode}" != "200" ];
    then
        echo "FAILURE: Deployed App is not accessible. Curl returned code ${retcode}"
        notifyFail
    else
        echo "SUCCESS: Deployed App is accessible. Curl returned code ${retcode}"
        notifyPass
    fi

    endTest
}


function testDeployedAppHTTPS()
{
    startTest

    retcode=$(curl --insecure -L -s -o /dev/null -w "%{http_code}" ${ADMIN_HTTPS_SHOPPING_CART_APP_URL} )

    if [ "${retcode}" != "200" ];
    then
        echo "FAILURE: Deployed App is not accessible. Curl returned code ${retcode}"
        notifyFail
    else
        echo "SUCCESS: Deployed App is accessible. Curl returned code ${retcode}"
        notifyPass
    fi

    endTest
}

function verifyAdminSystemService()
{

    startTest

    systemctl | grep "$WLS_ADMIN_SERVICE" > /tmp/debug.log 2>&1

    if [ $? == 1 ];
    then
        echo "FAILURE: Service $WLS_ADMIN_SERVICE not found"
        notifyFail
    else
        echo "SUCCESS: Service $WLS_ADMIN_SERVICE found"
        notifyPass
    fi

    endTest
}


#main

get_param "$@"

validate_input

testWLSDomainPath

testAdminConsoleHTTP

testAdminConsoleHTTPS

testServerStatus

#shoppingcart app already deployed in Admin Domain
testAppDeployment

testDeployedAppHTTP

testDeployedAppHTTPS

testAppUnDeployment

verifyAdminSystemService

printTestSummary

