#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $CURR_DIR/../utils/utils.sh

function setupDomain()
{
    print_heading "OPatch version"
    run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && \$WL_HOME/../OPatch/opatch version"

    print_heading "OPatch details"
    run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && \$WL_HOME/../OPatch/opatch lsinventory"

    print_heading "create cluster domain and verify"

    print_heading "installing git..."
    yum install -y git jq

    print_heading "download domain creation scripts..."
    run_as_oracle_user "mkdir -p /u01/app/scripts && rm -rf /u01/app/scripts/* && cd /u01/app/scripts && git clone https://github.com/gnsuryan/weblogic-cluster-domain-init"

    print_heading "kill any existing weblogic processes"
    pkill -9 -f weblogic.NodeManager
    pkill -9 -f weblogic.Server

    sleep 10s

    print_heading "cleanup domain directory..."
    run_as_oracle_user "rm -rf /u01/domains/*"

    print_heading "replace actual hostname in domain.properties"
    run_as_oracle_user "sed -i \"s/adminVM/$HOSTNAME/g\" /u01/app/scripts/weblogic-cluster-domain-init/domain.properties"

    print_heading "execute domain creation script"
    run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && cd /u01/app/scripts/weblogic-cluster-domain-init && java weblogic.WLST createDomain.py"

    print_heading "execute app deployment script"
    run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && cd /u01/app/scripts/weblogic-cluster-domain-init && java weblogic.WLST deployApps.py"

    print_heading "open ports for testing..."
    sudo firewall-cmd --zone=public --add-port=7001/tcp
    sudo firewall-cmd --zone=public --add-port=7002/tcp
    sudo firewall-cmd --zone=public --add-port=7003/tcp
    sudo firewall-cmd --zone=public --add-port=7004/tcp
    sudo firewall-cmd --runtime-to-permanent
    sudo systemctl restart firewalld
}


function testAdminConsole()
{
    startTest

    print_heading "Test Admin console and Test app deployed on the cluster"
    run_as_oracle_user "cd /u01/app/scripts/weblogic-cluster-domain-init && chmod +x testApp.sh && sh testApp.sh"

    if [ "$?" != "0" ];
    then
       echo "FAILURE - testAdminConsole"
       notifyFail
    else
       echo "SUCCESS - testAdminConsole"
       notifyPass
    fi

    endTest
}


function testServerRestart()
{
    startTest

    username=$(run_as_oracle_user "cat /u01/app/scripts/weblogic-cluster-domain-init/domain.properties | grep 'domain_username' | cut -d'=' -f 2")
    password=$(run_as_oracle_user "cat /u01/app/scripts/weblogic-cluster-domain-init/domain.properties | grep 'domain_password' | cut -d'=' -f 2")

    print_heading "Testing Server Restart..."
    run_as_oracle_user ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh && cd /u01/app/scripts/weblogic-cluster-domain-init && java weblogic.WLST testServerRestart.py $username $password t3://$HOSTNAME:7001"

    if [ "$?" != "0" ];
    then
       echo "FAILURE - testServerRestart"
       notifyFail
    else
       echo "SUCCESS - testServerRestart"
       notifyPass
    fi

    endTest
}


setupDomain

testAdminConsole

testServerRestart

