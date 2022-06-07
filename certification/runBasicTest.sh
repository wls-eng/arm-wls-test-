#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export RELEASE=/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server
. $RELEASE/bin/setWLSEnv.sh

export JAVA_HOME_ctl=$JAVA_HOME

export WLS_TESTROOT="$( readlink -f ${SCRIPT_DIR}/..)"
export T_WORK=$WLS_TESTROOT/work
export BUILDOUT=$T_WORK/buildout
export WLS_TEST_RESULTS=$T_WORK/resultout
export RESULTS_DIR=$T_WORK/resultout

mkdir -p $T_WORK $BUILDOUT $WLS_TEST_RESULTS $RESULTS_DIR

cd $WLS_TESTROOT/wlstest

. ./qaenv.sh

cd functional/core/certification

rm -f *.log

ant -f basic.test.xml clean build all -DazEnv=true | tee $RESULTS_DIR/basic_test_run.log

if grep -iq "not a clean run :-(" $RESULTS_DIR/basic_test_run.log
then
        echo "All tests didn't pass successfully"
        exit 1
else
        echo "All tests passed successfully"
fi

