#!/bin/bash


function usage()
{
  echo "$0 <SAS_URL>"
  echo "Example: $0 \"https://baseimageaccount.blob.core.windows.net/testsrc/wlstest.zip\""
  exit 1
}

if [ $# -ne 1 ];
then
  usage;
fi

SAS_URL="$1"
echo "SAS_URL: ${SAS_URL}"

mkdir -p /u01/app/workspace/

rm -rf /u01/app/workspace

cd /u01/app/workspace

curl -L -o wlstest.zip "${SAS_URL}"

unzip wlstest.zip

rm -rf wlstest.zip

