#!/bin/bash

PATCH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${PATCH_DIR}/../utils/utils.sh
source ${PATCH_DIR}/../utils/test_config.properties

function printLineSeparator()
{
    echo -e "\n===================================================================================\n"
}

#main

if [ $# -ne 1 ];
then
    echo "Invalid input: Please pass comma separated list of patches as argument"
    exit 1
fi

printLineSeparator

PATCH_LIST_TO_BE_CHECKED="$1"

cd $WLS_HOME/server/bin
. ./setWLSEnv.sh

printLineSeparator

java -version

printLineSeparator

java weblogic.version

printLineSeparator

lsinventory=$(runuser -l oracle -c "${WLS_HOME}/../OPatch/opatch lsinventory")
echo "$lsinventory"

printLineSeparator

uniquePatchList="$(echo "${lsinventory}"|grep "Unique Patch ID"|cut -d":" -f 2)"
uniquePatchList=`echo ${uniquePatchList} | sed -e 's/^[[:space:]]*//'`
echo "Unique Patch List: $uniquePatchList"

printLineSeparator

failed="false"

for PATCH in $(echo $PATCH_LIST_TO_BE_CHECKED | sed "s/,/ /g")
do
    if [[ $uniquePatchList == *"$PATCH"* ]]; then
        echo "$PATCH is available"
    else
        echo "$PATCH is not available"
        failed="true"
    fi
done

if [ "$failed" == "true" ];
then
    echo "Patch Verification Failed. "
    printLineSeparator
    notifyFail
else
    echo "Patch Verfication Successful."
    printLineSeparator
    notifyPass
fi

printTestSummary