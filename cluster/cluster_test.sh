#!/bin/bash

CLUSTER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${CLUSTER_DIR}/../utils/utils.sh
source ${CLUSTER_DIR}/../utils/test_config.properties

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

function isServerShutdown()
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

    if [ "$serverStatus" != "SHUTDOWN" ];
    then
        echo "FAILURE: Server $serverName not shutdown as expected."
        notifyFail
    else
        echo "SUCCESS: Server $serverName shutdown as expected."
        notifyPass
    fi
}


function shutdownServer()
{
    serverName="$1"

    print "Shutting down Server : $serverName"

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -d "{}" \
    -X POST ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/${serverName}/forceShutdown)

    print $output

    shutdownStatus="$(echo $output | jq -r '.progress')"

    if [ "$shutdownStatus" != "success" ];
    then
        echo "FAILURE: Server $serverName not shutdown as expected."
        notifyFail
    else
        echo "SUCCESS: Server $serverName shutdown as expected."
        notifyPass
    fi
}

function startServer()
{
    serverName="$1"

    print "Start Server : $serverName"

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -d "{}" \
    -X POST ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/${serverName}/start)

    print $output

    serverStartStatus="$(echo $output | jq -r '.progress')"

    if [ "$serverStartStatus" != "success" ];
    then
        echo "FAILURE: Server $serverName not started as expected."
        notifyFail
    else
        echo "SUCCESS: Server $serverName started as expected."
        notifyPass
    fi

    print "start Server : $serverName Successful"
}

function shutdownAllServers()
{

    print "ShutdownAllServers...."

     output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    #echo $output

    managedServers="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServers="$(echo $managedServers| tr '\n' ' ')"

    sleep 5s

    IFS=' '
    read -a managedServerArray <<< "$managedServers"

    for i in "${!managedServerArray[@]}";
    do
        serverName="${managedServerArray[$i]}"
        shutdownServer $serverName
        sleep 5s
    done

}


function startAllServers()
{

    print "StartAllServers...."

     output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    #echo $output

    managedServers="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServers="$(echo $managedServers| tr '\n' ' ')"

    sleep 5s

    IFS=' '
    read -a managedServerArray <<< "$managedServers"

    for i in "${!managedServerArray[@]}";
    do
        serverName="${managedServerArray[$i]}"
        startServer $serverName
        sleep 5s
    done
}

function getClusterName()
{

    startTest

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    print $output

    managedServers="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServers="$(echo $managedServers| tr '\n' ' ')"

    sleep 5s

    IFS=' '
    read -a managedServerArray <<< "$managedServers"

    for i in "${!managedServerArray[@]}";
    do
        serverName="${managedServerArray[$i]}"

        if [[ $serverName == *"Storage"* ]];
        then
          continue
        fi

        output=$(curl -s \
        --user ${WLS_USERNAME}:${WLS_PASSWORD} \
        -H X-Requested-By:MyClient \
        -H Accept:application/json \
        -H Content-Type:application/json \
        -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/serverConfig/servers/${serverName})

        CLUSTER_NAME="$(echo $output | jq -r '.cluster[1]')"

        print "ClusterName: $CLUSTER_NAME"

        break

    done

    endTest
}

function testManagedServerStatus()
{

    expectedStatus="$1"

    startTest

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name,state)

    print $output

    managedServer="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServerStatus="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .state')"

    managedServer=$(echo $managedServer)
    managedServerStatus=$(echo $managedServerStatus)

    IFS=' '
    read -a managedServerArray <<< "$managedServer"
    read -a managedServerStatusArray <<< "$managedServerStatus"

    for i in "${!managedServerArray[@]}";
    do
        serverName="${managedServerArray[$i]}"
        serverStatus="${managedServerStatusArray[$i]}"

        if [ "$expectedStatus" == "RUNNING" ];
        then
              isServerRunning "$serverName" "$serverStatus"
        else
          if [ "$expectedStatus" == "SHUTDOWN" ];
          then
              isServerShutdown "$serverName" "$serverStatus"
          fi
        fi
    done

    endTest
}

function testAppDeployment()
{

    mkdir -p /tmp/deploy
    cp ${SHOPPING_CART_APP_PATH} /tmp/deploy/
    chown -R oracle:oracle /tmp/deploy

    startTest

    retcode=$(curl -s \
            --user ${WLS_USERNAME}:${WLS_PASSWORD} \
            -H X-Requested-By:MyClient \
            -H Accept:application/json \
            -H Content-Type:application/json \
            -d "{
                name: '${SHOPPING_CART_APP_NAME}',
                deploymentPath: '/tmp/deploy/${SHOPPING_DEPLOY_APP}',
                targets:    [ '${CLUSTER_NAME}' ]
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


function testDeployedAppHTTP()
{
    startTest

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    print $output

    managedServers="$(echo $output | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')"
    managedServers="$(echo $managedServers| tr '\n' ' ')"

    sleep 5s

    IFS=' '
    read -a managedServerArray <<< "$managedServers"

    for i in "${!managedServerArray[@]}";
    do
        serverName="${managedServerArray[$i]}"

        if [[ $serverName == *"Storage"* ]];
        then
          continue
        fi

        output=$(curl -s \
        --user ${WLS_USERNAME}:${WLS_PASSWORD} \
        -H X-Requested-By:MyClient \
        -H Accept:application/json \
        -H Content-Type:application/json \
        -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/serverConfig/servers/${serverName})

        print "$output"

        serverListenPort="$(echo $output | jq -r '.listenPort')"
        machineName="$(echo $output| jq -r '.machine[1]')"
        print "machine: $machineName"

        output=$(curl -s \
        --user ${WLS_USERNAME}:${WLS_PASSWORD} \
        -H X-Requested-By:MyClient \
        -H Accept:application/json \
        -H Content-Type:application/json \
        -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/serverConfig/machines/${machineName}/nodeManager)

        print "$output"

        print "\n\n\********************************************\n\n"

        serverListenAddress="$(echo $output | jq -r '.listenAddress')"
        print "ServerListenAddress: $serverListenAddress"
        print "ServerListenPort: $serverListenPort"

        HTTP_SHOPPING_CART_APP_URL="http://${serverListenAddress}:$serverListenPort/shoppingcart"

        print "checking Shopping Cart URL: $HTTP_SHOPPING_CART_APP_URL"

        retcode=$(curl -L -s -o /dev/null -w "%{http_code}" ${HTTP_SHOPPING_CART_APP_URL} )

        if [ "${retcode}" != "200" ];
        then
            echo "FAILURE: Deployed App is not accessible on ${serverName}. Curl returned code ${retcode}"
            notifyFail
        else
            echo "SUCCESS: Deployed App is accessible on ${serverName}. Curl returned code ${retcode}"
            notifyPass
        fi

        print -e "\n\n********************************************\n\n\n"
        sleep 2s

    done

    endTest
}

function testAppUnDeployment()
{

    startTest

    retcode=$(curl -s \
            --user ${WLS_USERNAME}:${WLS_PASSWORD} \
            -H X-Requested-By:MyClient \
            -H Accept:application/json \
            -H Content-Type:application/json \
            -d "{
                targets:    [ '${CLUSTER_NAME}' ],
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


#main

get_param "$@"

validate_input

testManagedServerStatus "RUNNING"

getClusterName

testAppDeployment

testDeployedAppHTTP

shutdownAllServers

sleep 30s

testManagedServerStatus "SHUTDOWN"

startAllServers

sleep 30s

testManagedServerStatus "RUNNING"

testAppUnDeployment

printTestSummary

