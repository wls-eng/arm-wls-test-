#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $CURR_DIR/../utils/utils.sh

function testHostInfo()
{
    startTest

    hostnamectl | grep "$OS_VERSION" > /dev/null 2>&1

    if [ "$?" != "0" ];
    then
       echo "FAILURE: VM: OS Version verification failed. Expected $OS_VERSION"
       notifyFail
    else
       echo "SUCCESS: VM: OS version verified successfully"
       notifyPass
    fi

    endTest
}

function testWLSInstallPath()
{
    startTest

    print "WLS_HOME: ${WLS_HOME}"

    if [ ! -d "${WLS_HOME}" ]; then
      echo "FAILURE: Weblogic Server not installed as per the expected directory structure: ${WLS_HOME} "
      notifyFail
    else
      echo "SUCCESS: Weblogic Server install path verified successfully"
      notifyPass
    fi

    endTest
}

function testWLSVersion()
{
    startTest

    if [ ! -d "${WLS_HOME}" ]; then
      echo "Weblogic Server not installed as per the expected directory structure"
      notifyFail
    else

        cd ${WLS_HOME}/server/bin

        . ./setWLSEnv.sh > /dev/null 2>&1

        OUTPUT="$(java weblogic.version)"
        print "${OUTPUT}"

        echo "${OUTPUT}"|grep ${WLS_VERSION} > /dev/null 2>&1

        if [ "$?" != "0" ];
        then
           echo "FAILURE: Weblogic Server Version could not be verified "
           notifyFail
        else
           echo "SUCCESS: Weblogic Server Version verified successfully"
           notifyPass
        fi
    fi

    endTest "testWLSVersion"

}

function testJavaInstallPath()
{
    startTest

    cd ${WLS_HOME}/server/bin

    . ./setWLSEnv.sh > /dev/null 2>&1

    if [ ! -d "${JAVA_HOME}" ]; then
      echo "FAILURE: JAVA/JDK is not installed as per the expected directory structure: ${WLS_HOME} "
      notifyFail
    else
      echo "SUCCESS: JAVA/JDK installation path verified successfully"
      notifyPass
    fi

    endTest
}

function testJavaVersion()
{
    startTest

    cd ${WLS_HOME}/server/bin

    . ./setWLSEnv.sh > /dev/null 2>&1

    java -version 2> /tmp/java_version.txt

    cat /tmp/java_version.txt |grep "${JDK_VERSION}" > /dev/null 2>&1

    if [ "$?" != "0" ];
    then
       echo "FAILURE: Java Version could not be verified "
       notifyFail
    else
       echo "SUCCESS: Java Server Version verified successfully"
       notifyPass
    fi

    rm -f /tmp/java_version.txt

    endTest
}

function testJDBCDrivers()
{

    startTest

    if [[ -f "${WLS_HOME}/server/lib/${POSTGRESQL_JAR}" ]];
    then
        echo "SUCCESS: ${POSTGRESQL_JAR} file is found in Weblogic Server lib directory as expected"
        notifyPass
    else
        echo "FAILURE: ${POSTGRESQL_JAR} file is not found in Weblogic Server lib directory as expected"
        notifyFail
    fi

    endTest

    startTest

    if [[ -f "${WLS_HOME}/server/lib/${MSSQL_JAR}" ]];
    then
        echo "SUCCESS: ${MSSQL_JAR} file is found in Weblogic Server lib directory as expected"
        notifyPass
    else
        echo "FAILURE: ${MSSQL_JAR} file is not found in Weblogic Server lib directory as expected"
        notifyFail
    fi

    endTest

    startTest

    cd ${WLS_HOME}/server/bin

    . ./setWLSEnv.sh > /dev/null 2>&1

    echo ${WEBLOGIC_CLASSPATH} | grep "${POSTGRESQL_JAR}" > /dev/null 2>&1

    if [ $? == 1 ];
    then
        echo "FAILURE: ${POSTGRESQL_JAR} file is not found in Weblogic Classpath as expected"
        notifyFail
    else
        echo "SUCCESS: ${POSTGRESQL_JAR} file found in Weblogic Classpath as expected"
        notifyPass
    fi

    print "==========================================================================="

    echo ${WEBLOGIC_CLASSPATH} | grep "${MSSQL_JAR}" > /dev/null 2>&1

    if [ $? == 1 ];
    then
        echo "FAILURE: ${MSSQL_JAR} file is not found in Weblogic Classpath as expected"
        notifyFail
    else
        echo "SUCCESS: ${MSSQL_JAR} file found in Weblogic Classpath as expected"
        notifyPass
    fi

    endTest
}

function testRNGDService()
{

    startTest

    systemctl status rngd | grep "active (running)" > /dev/null 2>&1

    if [ "$?" != "0" ];
    then
        echo "FAILURE: rngd service not active"
        notifyFail
        endTest
        return
    else
        echo "SUCCESS: rngd service is active"
        notifyPass
    fi

    endTest

}

function testUtilities()
{
    isUtilityInstalled "zip"

    isUtilityInstalled "unzip"

    isUtilityInstalled "wget"

    isUtilityInstalled "rng"

    #isUtilityInstalled "cifs-utils"
}


#main

get_param "$@"

validate_input

testHostInfo

testWLSInstallPath

testWLSVersion

testJavaInstallPath

testJavaVersion

testJDBCDrivers

testRNGDService

testUtilities

printTestSummary

