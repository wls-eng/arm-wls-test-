#!/bin/bash

export UTILS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
#echo "UTILS_DIR: ${UTILS_DIR}"

export BASE_DIR="$(readlink -f $UTILS_DIR/..)"

usage()
{
cat << USAGE >&2
Usage:
    -i            INPUT_FILE        Path to Command input File
    -r            RG_NAME           Resource Group Name (Optional)
    -o            OTHER_ARGS        Comma separated list of arguments in keyvalue pair (Optional)
    -h|?|--help   HELP              Help/Usage info

ex: $0 -i /test_input/OL7.6_14.1.1.0.0_JDK8.props -r MyResourceGrp

USAGE

exit 1
}

function run_as_oracle_user()
{
    command="$1"
    runuser -l oracle -c "$command"
}

function print()
{
  if [ "$DEBUG" == "true" ];
  then
   message="$1"
   echo -e "$1"
  fi
}

get_param()
{
    while [ "$1" ]
    do
        case $1 in
         -i         )  INPUT_FILE=$2 ;;
         -r         )  RG_NAME=$2;;
         -o         )  OTHER_ARGS=$2;;
                   *)  echo 'invalid arguments specified'
                       usage;;
        esac
        shift 2
    done
}

read_other_args()
{
  if [ ! -z "$OTHER_ARGS" ];
  then
    IFS=','
    read -ra ARGS <<< "$OTHER_ARGS"
    for i in "${ARGS[@]}";
    do
        eval "export $i"
    done
  fi
}


validate_input()
{
    if [ -z "$INPUT_FILE" ];
    then
        echo "command input file not provided"
        usage;
    fi

    if [[ ! -f "$INPUT_FILE" ]];
    then
        echo "Provided input file ${INPUT_FILE} not found"
        exit 1
    fi

    if [[ -z "$RG_NAME" ]];
    then
        echo "command input RG_NAME not provided"
    fi

    if [[ -z "$OTHER_ARGS" ]];
    then
       echo "command input OTHER_ARGS not provided"
    fi

    echo "Using input file $INPUT_FILE"
    source $INPUT_FILE

    read_other_args
}

function notifyPass()
{
    passcount=$((passcount+1))
}

function notifyFail()
{
    failcount=$((failcount+1))
}

function printTestSummary()
{
    exitOnFailure="$1"

    if [ -z "$exitOnFailure" ];
    then
       exitOnFailure="true"
    fi

    printf "\n     TEST EXECUTION SUMMARY"
    printf "\n     ++++++++++++++++++++++   \n"
    printf "       NO OF TEST PASSED:  ${passcount} \n"
    printf "       NO OF TEST FAILED:  ${failcount} \n"

    if [ "$exitOnFailure" == "true" ];
    then
      if [ $failcount -gt 0 ];
      then
        exit 1
      fi
    fi
}

function startTest()
{
    TEST_INFO="${FUNCNAME[1]}"
    print "\n\n"
    print " -----------------------------------------------------------------------------------------"
    print " TEST EXECUTION START:  >>>>>>     ${TEST_INFO}      <<<<<<<<<<<<<<<<<<<"
}

function endTest()
{
    TEST_INFO="${FUNCNAME[1]}"
    print " TEST EXECUTION  END :   >>>>>>     ${TEST_INFO}      <<<<<<<<<<<<<<<<<<<"
    print " -----------------------------------------------------------------------------------------"
    print "\n\n"

    printDebugLog

    #printTestSummary "false" "$TEST_INFO"
}

function printDebugLog()
{
    if [ "$DEBUG" == "true" ];
    then
      if [ -f /tmp/debug.log ];
      then
       cat /tmp/debug.log
       sleep 1s
       rm -f /tmp/debug.log
      fi
    else
       rm -f /tmp/debug.log
    fi

}

function print_heading()
{
  text="$1"
  print "\n################ $text #############\n"
  print "-----------------------------------------------------\n"
}

function isUtilityInstalled()
{
    startTest

    utilityName="$1"

    yum list installed | grep "$utilityName" > /tmp/debug.log 2>&1

    if [ "$?" != "0" ];
    then
       echo "FAILURE: Utility $utilityName not found."
       notifyFail
    else
       echo "SUCCESS: Utility $utilityName found."
       notifyPass
    fi

    if [ "$DEBUG" == "true" ];
    then
      cat /tmp/debug.log
    else
       rm -f /tmp/debug.log
    fi

    endTest
}


function testWDTInstallation()
{

    if [ ! -d "$WDT_HOME" ];
    then
        print "FAILURE: Weblogic Deploy Tool not found"
        notifyFail
        endTest
        return
    else
        print "SUCCESS: Weblogic Deploy Tool found"
        notifyPass

        $WDT_HOME/bin/createDomain.sh

        if [ "$?" != "0" ];
        then
            print "FAILURE: Failed to verify Deploy Tool"
            notifyFail
        else
            print "SUCCESS: Deploy tool verified successfully"
            notifyPass
        fi
    fi

    endTest
}

source ${UTILS_DIR}/test_config.properties

export passcount=0
export failcount=0


