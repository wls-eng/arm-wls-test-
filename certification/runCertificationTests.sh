#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function usage()
{
  echo "$0 <SAS_URL> <JDBC_URL> <DB_USER> <DB_PASSWORD>"
  echo "Example: $0 \"https://baseimageaccount.blob.core.windows.net/testsrc/wlstest.zip\" \"jdbc:oracle:thin:@sampledb.eastus.cloudapp.azure.com:1521:myoradb\" \"sys as sysdba\" \"OraPasswd1\""
  exit 1
}

function read_args()
{

   echo "args: $#"
   if [ $# -ne 4 ];
   then
       usage;
   fi

   SAS_URL="$1"
   JDBC_URL="$2"
   DB_USER="$3"
   DB_PASSWORD="$4"

}

function install_git()
{
  yum install -y git

  git --version

  if [ "$?" != "0" ];
  then
    echo "git not installed. Please try again"
    exit 1
  fi
}

function install_jq()
{

 yum install -y jq

 jq --version

 if [ "$?" != "0" ];
 then
   echo "JQ not installed. Trying installation again using EPEL latest release 7"
   rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
   yum install -y jq
 fi

 jq --version

 if [ "$?" != "0" ];
 then
   echo "JQ installation failed. Please correct the issue and try again "
   exit 1
 fi
}

function install_nginx()
{
   ./installNginx.sh

   if [ $? != 0 ];
   then
     echo "Error while installing and configuring nginx"
     exit 1
   fi

}

function setup_certification_tests()
{
   ${SCRIPT_DIR}/setupCertificationTest.sh "${SAS_URL}" "${JDBC_URL}" "${DB_USER}" "${DB_PASSWORD}"

   if [ $? != 0 ];
   then
     echo "Error while setting up certification tests on Azure"
     exit 1
   fi
}


function run_certification_tests()
{
   mkdir -p /u01/app/git/scripts

   cp -rf ${SCRIPT_DIR}/*.sh /u01/app/git/scripts/

   chown -R oracle:oracle /u01/app/git/scripts/

   su - oracle -c "/u01/app/git/scripts/runBasicTest.sh"

   su - oracle -c "/u01/app/git/scripts/runJMSFailOverTest.sh"

   su - oracle -c "/u01/app/git/scripts/runJDBCFailOverTest.sh"
}

#main

read_args "$@"

install_git

install_jq

install_nginx

setup_certification_tests

run_certification_tests
