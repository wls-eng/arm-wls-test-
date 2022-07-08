#!/bin/bash


function usage()
{
  echo "$0 <SAS_URL> <JDBC_URL> <DB_USER> <DB_PASSWORD>"
  echo "Example: $0 \"https://baseimageaccount.blob.core.windows.net/testsrc/wlstest.zip\" \"jdbc:oracle:thin:@sampledb.eastus.cloudapp.azure.com:1521:myoradb\" \"sys as sysdba\" \"OraPasswd1\""
  exit 1
}

if [ $# -ne 4 ];
then
  usage;
fi

SAS_URL="$1"
JDBC_URL="$2"
DB_USER="$3"
DB_PASSWORD="$4"

echo "SAS_URL: ${SAS_URL}"
echo "JDBC_URL: ${JDBC_URL}"
echo "DB_USER: ${DB_USER}"
echo "DB_PASSWORD: ${DB_PASSWORD}"

mkdir -p /u01/app/workspace/

rm -rf /u01/app/workspace/*

cd /u01/app/workspace

curl -L -o wlstest.zip "${SAS_URL}"

if [ ! -f /u01/app/workspace/wlstest.zip ];
then
  echo "wlstest.zip file not downloaded"
  exit 1
fi

unzip wlstest.zip

if [ $? != 0 ];
then
  echo "Error while unzipping wlstest.zip . Please check if wlstest.zip is downloaded or if it is a valid zip file"
  exit 1
fi

rm -rf wlstest.zip

AZURE_CERTIFICATION_CONFIG_FILE="/u01/app/workspace/wlstest/functional/core/certification/common/config/azure_config/t3_config.properties"

echo "replacing JDBC datasource url, username and password details in azure config file"
sed -i "s/datasource.url=.*/datasource.url=${JDBC_URL}/g" ${AZURE_CERTIFICATION_CONFIG_FILE}
sed -i "s/datasource.username=.*/datasource.username=\"${DB_USER}\"/g" ${AZURE_CERTIFICATION_CONFIG_FILE}
sed -i "s/datasource.password=.*/datasource.password=\"${DB_PASSWORD}\"/g" ${AZURE_CERTIFICATION_CONFIG_FILE}

chown -R oracle:oracle /u01/app/workspace

