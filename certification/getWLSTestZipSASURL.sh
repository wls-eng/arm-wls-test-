#!/bin/bash

if [ ${_} == ${0} ]; then
    echo "Invalid command: Please use . ./getWLSTestSASURL.sh to fetch the SAS URL."
    echo "On Successful execution, the SAS URL will be available in the SAS_URL environment variable"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

rm -f ${SCRIPT_DIR}/wlstest.zip

ACCOUNT_KEY=$(az storage account keys list -g DO-NOT-DELETE-base-image-binaries -n baseimageaccount --query [0].value -o tsv)

EXPIRY_DATE=`date -u -d "10 minutes" '+%Y-%m-%dT%H:%MZ'`

SAS_URL=$(az storage blob generate-sas --full-uri -c testsrc --account-name baseimageaccount -n wlstest.zip --account-key ${ACCOUNT_KEY} --expiry "${EXPIRY_DATE}" --permissions r)

temp="${SAS_URL%\"}"
temp="${temp#\"}"
SAS_URL="$temp"

echo "SAS_URL: $SAS_URL"

export SAS_URL

echo "Downloading wlstest.zip from $SAS_URL and validating"

wget "$SAS_URL" -q -k -O ${SCRIPT_DIR}/wlstest.zip

if [ -f ${SCRIPT_DIR}/wlstest.zip ];
then
  echo "wlstest.zip downloaded successfully"
else
  echo "wlstest.zip download failed"
  exit 1
fi

unzip -qq -t ${SCRIPT_DIR}/wlstest.zip
result=$?

rm -f ${SCRIPT_DIR}/wlstest.zip

if [ $result == 0 ];
then
  echo "wlstest.zip validated successfully"
else
  echo "wlstest.zip validation failed"
  exit 1
fi

