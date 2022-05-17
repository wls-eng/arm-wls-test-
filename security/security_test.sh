#!/bin/bash

SECURITY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function getDomainName()
{
   output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -d "{}" \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainConfig)

    #print "$output"

    domainName=$(echo "$output" | jq -r '.name')

    print "DomainName: $domainName"
}

#main

source ${SECURITY_DIR}/../utils/utils.sh
source ${SECURITY_DIR}/../utils/test_config.properties

get_param "$@"

validate_input

getDomainName

ADMIN_SECURITY_DIR="/u01/domains/${domainName}/servers/${ADMIN_SERVER_NAME}/security"
ADMIN_BOOTPROPS_FILE="/u01/domains/${domainName}/servers/${ADMIN_SERVER_NAME}/security/boot.properties"

print "ADMIN_SECURITY_DIR: ${ADMIN_SECURITY_DIR}"
print "ADMIN_BOOTPROPS_FILE: ${ADMIN_BOOTPROPS_FILE}"


if [ ! -d "${ADMIN_SECURITY_DIR}" ];
then
  echo "FAILURE: Domain Admin Server Security Directory doesn't exist"
  notifyFail
else
  echo "SUCCESS: Domain Admin Server Security Directory exists"
  notifyPass
fi

if [ ! -f "${ADMIN_BOOTPROPS_FILE}" ];
then
  echo "FAILURE: Domain Admin Server Security Boot Properties File doesn't exist"
  notifyFail
else
  echo "SUCCESS: Domain Admin Server Security Boot Properties exists"
  notifyPass
fi

UMASK_ADMIN_SECURITY_DIR="$(stat -c %a ${ADMIN_SECURITY_DIR})"
UMASK_ADMIN_ADMIN_BOOTPROPS_FILE="$(stat -c %a ${ADMIN_BOOTPROPS_FILE})"

print "UMASK_ADMIN_SECURITY_DIR: ${UMASK_ADMIN_SECURITY_DIR}"
print "UMASK_ADMIN_ADMIN_BOOTPROPS_FILE: ${UMASK_ADMIN_ADMIN_BOOTPROPS_FILE}"

if [ "${UMASK_ADMIN_SECURITY_DIR}" == "740" ];
then
  echo "SUCCESS: umask for Admin Security Directory is set to 740 (umas 027) as required"
  notifyPass
else
  echo "FAILURE: umask for Admin Security Directory is not set to 740 (umask 027) as required"
  notifyFail
fi

if [ "${UMASK_ADMIN_ADMIN_BOOTPROPS_FILE}" == "740" ];
then
  echo "SUCCESS: umask for Admin Security Boot Properties File is set to 740 (umas 027) as required"
  notifyPass
else
  echo "FAILURE: umask for Admin Security Boot Properties File is not set to 740 (umask 027) as required"
  notifyFail
fi

output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -d "{}" \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/domainConfig/securityConfiguration)

print "$output"

REMOTE_ANONYMOUS_RMIT3_ENABLED=$(echo "$output" | jq -r '.remoteAnonymousRMIT3Enabled')

print "REMOTE_ANONYMOUS_RMIT3_ENABLED: ${REMOTE_ANONYMOUS_RMIT3_ENABLED}"

if [ "${REMOTE_ANONYMOUS_RMIT3_ENABLED}" == "false" ];
then
  echo "SUCCESS: Remote Anonymous RMIT3 Enabled MBean is set to false as required"
  notifyPass
else
  echo "FAILURE: Remote Anonymous RMIT3 Enabled MBean is not set to false as required"
  notifyFail
fi


printTestSummary
