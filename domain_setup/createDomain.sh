#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $CURR_DIR/domain.properties

. $WLS_HOME/server/bin/setWLSEnv.sh

echo "creating cluster domain..."
java weblogic.WLST createDomain.py

echo "deploying replicationwebapp on cluster"
java weblogic.WLST deployApps.py
