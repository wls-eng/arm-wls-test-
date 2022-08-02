#!/bin/bash

DATASOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${DATASOURCE_DIR}/../utils/utils.sh
source ${DATASOURCE_DIR}/../utils/test_config.properties

function usage()
{
  echo "usage"
  echo "$0 -i <test-input-file> -o DS_JNDI=<JNDI_NAME>,DB_TYPE=<DB_TYPE>"
  echo "DB_TYPE --> postgresql,sqlserver,oracle"
  echo "example: $0 -i test_input/weblogic-141100-jdk8-ol76.props -o DS_JNDI=jndi/postgresql,DB_TYPE=postgresql"
  exit 1
}
function validate_other_args()
{
    if [ -z "${DS_JNDI}" ] || [ -z "${DB_TYPE}" ]
    then
      usage;
    fi
}

function verifyJDBCDataSource()
{
    echo "verifying JDBC Datasource..."

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/tenant-monitoring/datasources)

    result=$(echo "$output" | jq -r '.body.items[].instances[].state'| grep -i Running)

    if [[ "$result" == **"Running"** ]];
    then
        echo "SUCCESS: JDBC Datasource connection is successful."
        notifyPass
    else
        echo "FAILURE: Database connection is not successful. Please check Datasource configuration and try again."
        notifyFail
    fi
}

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

    adminServerName=$(echo "$output" | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name | test($ADMIN_NAME;"i")) | .name ')

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
        echo "FAILURE: JDBC Driver Info App Deployment Failed. Deployment Status: ${deploymentStatus}"
        notifyFail
    else
        echo "SUCCESS: JDBC Driver Info App Deployed Successfully. Deployment Status: ${deploymentStatus}"
        notifyPass
    fi
    rm -rf /tmp/deploy

    print "Wait for 15 seconds for the deployed Apps to become available..."
    sleep 15s

    endTest
}

function verifyJDBCDriverVersion()
{

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes?links=none&fields=name)

    print "output: $output"

    managedServers=$(echo "$output" | jq -r --arg ADMIN_NAME "$ADMIN_SERVER_NAME" '.items[]|select(.name| test($ADMIN_NAME;"i") | not ) | .name')
    managedServers=$(echo "$managedServers"| tr '\n' ' ')

    managedServers="$(echo $managedServers|xargs)"
    print "managedServers: $managedServers"

    if [ -z "$managedServers" ];
    then
        print "verifying jdbc driver using admin server"
        T3_SERVER_URL="t3://adminVM:7001"
        verifyJDBCDriver "${T3_SERVER_URL}" "${DS_JNDI}"
        return
    fi

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

        serverListenPort=$(echo "$output" | jq -r '.listenPort')
        machineName=$(echo "$output"| jq -r '.machine[1]')
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

        T3_SERVER_URL="t3://${serverListenAddress}:$serverListenPort"

        print "checking JDBC Driver version using URL: $T3_SERVER_URL $DS_JNDI"

        verifyJDBCDriver "$T3_SERVER_URL" "$DS_JNDI"

        print -e "\n\n********************************************\n\n\n"
        sleep 2s

    done

}

function verifyJDBCDriver()
{
    lookupURL="$1"
    DS_JNDI="$2"

    print "verifying JDBC Driver for T3 URL $lookupURL ..."

    output=$(curl -s \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -X GET "${HTTP_ADMIN_URL}/jdbcDriverInfo/JDBCDriverInfoServlet?dsname=${DS_JNDI}&lookupURL=${lookupURL}")

    print "REST Endpoint: ${HTTP_ADMIN_URL}/jdbcDriverInfo/JDBCDriverInfoServlet?dsname=${DS_JNDI}&lookupURL=${lookupURL}"
    print "$output"

    result=$(echo "$output" | jq -r '.result'| grep -i SUCCESS)

    if [ "$result" != "SUCCESS" ];
    then
        echo "FAILURE: JDBC Driver Verify Application is not accessible for $lookupURL ."
        notifyFail
    else
        echo "SUCCESS: JDBC Driver verify Application is accessible for $lookupURL ."
        notifyPass
    fi

    DRIVER_VERSION=$(echo "$output" | jq -r '.DriverVersion')
    echo "DRIVER VERSION: $DRIVER_VERSION"

    if [ -z "${DB_TYPE}" ];
    then
       echo "FAILURE: DB_TYPE Parameter not provided"
       notifyFail
    else
        if [ "${DB_TYPE}" == "postgresql" ];
        then
          if [ "${DRIVER_VERSION}" == "${POSTGRESQL_DRIVER_VERSION}" ];
          then
             echo "SUCCESS: Postgresql driver version verification successful for $lookupURL"
             notifyPass
          else
             echo "FAILURE: Postgresql driver version verification failed for $lookupURL"
             notifyFail
          fi
        fi

        if [ "${DB_TYPE}" == "sqlserver" ];
        then
          if [ "${DRIVER_VERSION}" == "${MSSQL_DRIVER_VERSION}" ];
          then
             echo "SUCCESS: MSSQL driver version verification successful for $lookpURL"
             notifyPass
          else
             echo "FAILURE: MSSQL driver version verification failed for $lookupURL"
             notifyFail
          fi
        fi
    fi
}


#main

get_param "$@"

validate_input

validate_other_args

verifyJDBCDataSource

if [ -z "$DS_JNDI" ];
then
  echo "FAILURE: Datasource JNDI name not provided "
  notifyFail
else
  testJDBCDriverInfoAppDeployment
  verifyJDBCDriverVersion
fi

printTestSummary


