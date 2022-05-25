#!/bin/bash

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $CURR_DIR/domain.properties

kill -9 `ps -aef | grep 'weblogic.Name=AdminServer' | grep -v grep | awk '{print $2}'` || true

echo "Deleting domain directory... ${DOMAIN_DIR}"

rm -f ${DOMAIN_DIR}/*
rm -rf ${DOMAIN_DIR}
