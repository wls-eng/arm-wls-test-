#!/bin/bash

SSL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${SSL_DIR}/../utils/utils.sh
source ${SSL_DIR}/../utils/test_config.properties

function usage()
{
   cat << USAGE >&2
Usage:
    -i            INPUT_FILE        Path to Command input File
    -r            RG_NAME           Resource Group Name (Optional)
    -o            OTHER_ARGS        Comma separated list of arguments in keyvalue pair (Optional)
    -h|?|--help   HELP              Help/Usage info

ex: $0 -i /test_input/OL7.6_14.1.1.0.0_JDK8.props -r MyResourceGrp -o CERT_TYPE=CUSTOMCERT

USAGE
exit 1
}

function validateDemoCert()
{
   if [ "$keyStores" == "DemoIdentityAndDemoTrust" ];
   then
      echo "SUCCESS: Demo Keystores $keyStores verified successfully"
      notifyPass
   else
      echo "FAILURE: Demo Keystores $keyStores verification failed"
      notifyFail
   fi

   vaildateCustomHostNameVerifier
}

function vaildateCustomHostNameVerifier()
{
   if [ "$hostnameVerifier" == "com.oracle.azure.weblogic.security.util.WebLogicCustomHostNameVerifier" ];
   then
      echo "SUCCESS: Custom HostnameVerifier verified successfully"
      notifyPass
   else
      echo "FAILURE: Custom HostnameVerifier verification failed"
      notifyFail
   fi

   if [ "$hostnameVerificationIgnored" == "false" ];
   then
      echo "SUCCESS: Custom HostnameVerifierIgnored set to false as required"
      notifyPass
   else
      echo "FAILURE: Custom HostnameVerifierIgnored not set to false as required"
      notifyFail
   fi

   su -c ". /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh > /dev/null 2>&1; echo \$WEBLOGIC_CLASSPATH | grep -i 'hostnamevalues.jar' | grep -i 'weblogicustomhostnameverifier.jar' > /dev/null 2>&1 " oracle

   if [ "$?" != "0" ];
   then
     echo "FAILURE: Failed to find hostnamevalues.jar and weblogicustomhostnameverifier.jar in WEBLOGIC_CLASSPATH"
     notifyFail
   else
     echo "SUCCESS: Successfully verified inclusion of hostnamevalues.jar and weblogicustomhostnameverifier.jar in WEBLOGIC_CLASSPATH"
     notifyPass
   fi

   su -c "test -f /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/weblogicustomhostnameverifier.jar && test -f /u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/hostnamevalues.jar" oracle

   if [ "$?" != "0" ];
   then
     echo "FAILURE: Failed to find hostnamevalues.jar and weblogicustomhostnameverifier.jar in Weblogic Server lib path"
     notifyFail
   else
     echo "SUCCESS: Successfully found hostnamevalues.jar and weblogicustomhostnameverifier.jar in Weblogic Server lib path"
     notifyPass
   fi

}

function validateCustomCert()
{
   if [ "$keyStores" == "CustomIdentityAndCustomTrust" ];
   then
      echo "SUCCESS: Custom Keystores $keyStores verified successfully"
      notifyPass
   else
      echo "FAILURE: Keystores $keyStores verification failed"
      notifyFail
   fi

   if [ "$customIdentityKeyStoreFileName" == "/u01/domains/${domainName}/keystores/identity.keystore" ];
   then
      echo "SUCCESS: Custom Identity Keystore Path verified successfully"
      notifyPass
   else
      echo "FAILURE:Custom Identity Keystore Path verification failed"
      notifyFail
   fi

   if [ "$customTrustKeyStoreFileName" == "/u01/domains/${domainName}/keystores/trust.keystore" ];
   then
      echo "SUCCESS: Custom Trust Keystore Path verified successfully"
      notifyPass
   else
      echo "FAILURE:Custom Trust Keystore Path verification failed"
      notifyFail
   fi

   vaildateCustomHostNameVerifier
}

get_param "$@"

validate_input

output=$(curl -L --insecure --write-out '%{http_code}' --silent --output /dev/null https://${ADMIN_HOST}:${ADMIN_SSL_PORT}/console)

if [ "$output" == "200" ];
then
  echo "SUCCESS: Admin console accessible on SSL Port"
  notifyPass
else
  echo "FAILURE: Admin console not accessible on SSL Port"
  notifyFail
fi

CN=$(echo | openssl s_client -showcerts -servername ${ADMIN_HOST} -connect ${ADMIN_HOST}:${ADMIN_SSL_PORT} 2>/dev/null | openssl x509 -inform pem -out server.crt)

# Replace any spaces between certificate parameters like CN = adminVM to CN=adminVM and then grep
openssl x509 -noout -subject -in server.crt | sed 's/^[[:blank:]]*//; s/[[:blank:]]*$//; s/[[:blank:]]\{1,\}//g' | grep -i "CN=${ADMIN_HOST}" > /dev/null 2>&1

if [ "$?" != "0" ];
then
  echo "FAILURE: SSL Certification Common Name (CN) verification Failed"
  notifyFail
else
  echo "SUCCESS: SSL Certificate Common Name (CN) verification successful"
  notifyPass
fi

startdate=$(date --date="$(openssl x509 -noout -startdate -in server.crt | cut -d= -f 2)" --iso-8601)
enddate=$(date --date="$(openssl x509 -noout -enddate -in server.crt | cut -d= -f 2)" --iso-8601)
today=`date +%Y-%m-%d`

print $startdate
print $enddate
print $today

if expr "$startdate" "<=" "$today" > /dev/null;
then
   if expr "$today" "<=" "$enddate" > /dev/null;
   then
     echo "SUCCESS: Certificate is still valid and has not expired"
   else
     echo "FAILURE: SSL Certificate has expired"
   fi
else
   echo "FAILURE: SSL Certificate has expired"
fi


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

output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -d "{}" \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/serverConfig/servers/${ADMIN_SERVER_NAME})

print "$output"

customIdentityKeyStoreFileName=$(echo "$output" | jq -r '.customIdentityKeyStoreFileName')
customTrustKeyStoreFileName=$(echo "$output" | jq -r '.customTrustKeyStoreFileName')
keyStores=$(echo "$output" | jq -r '.keyStores')

print "customIdentityKeyStoreFileName=$customIdentityKeyStoreFileName"
print "customTrustKeyStoreFileName=$customTrustKeyStoreFileName"
print "keyStores=$keyStores"

output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -d "{}" \
    -X GET ${HTTP_ADMIN_URL}/management/weblogic/latest/serverConfig/servers/${ADMIN_SERVER_NAME}/SSL)

print "$output"

hostnameVerifier=$(echo "$output" | jq -r '.hostnameVerifier')
hostnameVerificationIgnored=$(echo "$output" | jq -r '.hostnameVerificationIgnored')

print "hostnameVerifier=$hostnameVerifier"
print "hostnameVerificationIgnored=$hostnameVerificationIgnored"

if [ "$CERT_TYPE" == "CUSTOMCERT" ];
then
    validateCustomCert
else
    validateDemoCert
fi

printTestSummary
