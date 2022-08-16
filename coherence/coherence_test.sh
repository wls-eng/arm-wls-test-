#!/bin/bash

DATASOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${DATASOURCE_DIR}/../utils/utils.sh
source ${DATASOURCE_DIR}/../utils/test_config.properties

function verifyCoherenceClusterName()
{
    print "verifying Coherence Cluster Name..."

cat << EOF >> $SCRIPT_DIR/verifyCoherenceClusterName.py

connect("${WLS_USERNAME}","${WLS_PASSWORD}","${T3_ADMIN_URL}")
cd("/CoherenceClusterSystemResources/${COHERENCE_CLUSTER_NAME}/CoherenceClusterResource/${COHERENCE_CLUSTER_NAME}")
coherenceClusterName=cmo.getName()

print 'coherence cluster: '+coherenceClusterName

if coherenceClusterName != "${COHERENCE_CLUSTER_NAME}":
  print 'Coherence Cluster Name verification failed'
  raise Exception('Coherence Cluster Name verification failed')
else:
  print 'Coherence Cluster Name verification complete'

disconnect()
exit()

EOF

runuser -l oracle -c ". ${ORACLE_HOME}/oracle_common/common/bin/setWlstEnv.sh; java weblogic.WLST ${SCRIPT_DIR}/verifyCoherenceClusterName.py ${REDIRECT_OUTPUT}"
if [[ $? != 0 ]]; then
  echo "FAILURE: Coherence Cluster name verification failed"
  notifyFail
else
  echo "SUCCESS: Coherence Cluster name verification is successful."
  notifyPass
fi

}

function verifyCoherenceClusterMemberSize()
{
    print "verifying Coherence Cluster MemberSize..."

EXPECTED_COHERENCE_CLUSTER_SIZE=$((${DEFAULT_CLUSTER_SIZE}+${DEFAULT_NUM_OF_COHERENCE_SERVERS}))
print "Expected Coherence Cluster size: $EXPECTED_COHERENCE_CLUSTER_SIZE"

cat << EOF >> $SCRIPT_DIR/verifyCoherenceClusterMemberSize.py

connect("${WLS_USERNAME}","${WLS_PASSWORD}","${T3_ADMIN_URL}")
cd("/CoherenceClusterSystemResources/${COHERENCE_CLUSTER_NAME}/Targets")
memberListMap=ls(pwd(), returnMap='true')

if len(memberListMap) != ${EXPECTED_COHERENCE_CLUSTER_SIZE} :
  print "Coherence Cluster size not matching with expected value"
  raise Exception('Coherence Cluster size not matching with expected value')
else:
  print "Coherence Cluster size matching with expected value"

disconnect()
exit()

EOF

runuser -l oracle -c ". ${ORACLE_HOME}/oracle_common/common/bin/setWlstEnv.sh; java weblogic.WLST ${SCRIPT_DIR}/verifyCoherenceClusterMemberSize.py ${REDIRECT_OUTPUT}"
if [[ $? != 0 ]]; then
  echo "FAILURE: Coherence Cluster size verification failed"
  notifyFail
else
  echo "SUCCESS: Coherence Cluster size verification is successful."
  notifyPass
fi

}

function verifyCoherenceClusterMemberList()
{
   expectedMemberList=""

   print "verifying Coherence Cluster MemberList..."

   for ((i=1;i<=DEFAULT_CLUSTER_SIZE;i++));
   do
       expectedMemberId="${MANAGED_SERVER_PREFIX}${i}"
       if [ -z "${expectedMemberList}" ];
       then
          expectedMemberList="${expectedMemberId}"
       else
          expectedMemberList="${expectedMemberList},${expectedMemberId}"
       fi
   done

   for ((i=1;i<=DEFAULT_NUM_OF_COHERENCE_SERVERS;i++));
   do
       expectedMemberId="${COHERENCE_SERVER_PREFIX}${i}"
       if [ -z "${expectedMemberList}" ];
       then
          expectedMemberList="${expectedMemberId}"
       else
          expectedMemberList="${expectedMemberList},${expectedMemberId}"
       fi
   done

   print "expected MemberList: ${expectedMemberList}"

cat << EOF >> $SCRIPT_DIR/verifyCoherenceClusterMemberList.py

connect("${WLS_USERNAME}","${WLS_PASSWORD}","${T3_ADMIN_URL}")
cd("/CoherenceClusterSystemResources/${COHERENCE_CLUSTER_NAME}/Targets")
memberListMap=ls(pwd(), returnMap='true')

expectedMemberListString="${expectedMemberList}"
expectedMemberList=list(expectedMemberListString.split(","))

if len(expectedMemberList) != len(memberListMap):
  raise Exception("Expected Member List and Actual Member List differ")

for x in expectedMemberList:
  if x not in memberListMap:
     raise Exception("Expected Member List and Actual Member List differ")

print 'Expected Member List and Actual Member list are same'

disconnect()
exit()

EOF

runuser -l oracle -c ". ${ORACLE_HOME}/oracle_common/common/bin/setWlstEnv.sh; java weblogic.WLST ${SCRIPT_DIR}/verifyCoherenceClusterMemberList.py ${REDIRECT_OUTPUT}"
if [[ $? != 0 ]]; then
  echo "FAILURE: Coherence Cluster List verification failed"
  notifyFail
else
  echo "SUCCESS: Coherence Cluster List verification is successful."
  notifyPass
fi

}

function verifyCoherenceServerStatus()
{
   print "verifying Coherence Server Status"

cat << EOF >> $SCRIPT_DIR/verifyCoherenceServerStatus.py

connect("${WLS_USERNAME}","${WLS_PASSWORD}","${T3_ADMIN_URL}")
serverConfig()
servers = cmo.getServers()
domainRuntime()
for server in servers:
    print server.getName()
    if server.getName().startswith("${COHERENCE_SERVER_PREFIX}"):
       cd("/ServerRuntimes/" + server.getName())
       state = cmo.getState()
       print "server state: "+state
       if state == "RUNNING":
           print server.getName()+ " is Running"
       else:
           raise Exception("Coherence Server : "+server.getName()+" not running")

disconnect()
exit()

EOF

runuser -l oracle -c ". ${ORACLE_HOME}/oracle_common/common/bin/setWlstEnv.sh; java weblogic.WLST ${SCRIPT_DIR}/verifyCoherenceServerStatus.py ${REDIRECT_OUTPUT}"
if [[ $? != 0 ]]; then
  echo "FAILURE: Coherence Cluster List verification failed"
  notifyFail
else
  echo "SUCCESS: Coherence Cluster List verification is successful."
  notifyPass
fi

}


#main

ORACLE_HOME="/u01/app/wls/install/oracle/middleware/oracle_home"
SCRIPT_DIR="/tmp/script"

if [ "${DEBUG}" == "true" ];
then
  REDIRECT_OUTPUT=""
else
  REDIRECT_OUTPUT=">\/dev\/null 2>&1"
fi


mkdir -p ${SCRIPT_DIR}
rm -rf ${SCRIPT_DIR}/*.py

get_param "$@"

validate_input

verifyCoherenceClusterName

verifyCoherenceClusterMemberSize

verifyCoherenceClusterMemberList

verifyCoherenceServerStatus

printTestSummary
