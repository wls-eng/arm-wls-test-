#!/bin/bash

DATASOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${DATASOURCE_DIR}/../utils/utils.sh
source ${DATASOURCE_DIR}/../utils/test_config.properties

function verifyCoherenceCluster()
{
    print "verifying Coherence Cluster..."

    output=$(curl -s \
    --user ${WLS_USERNAME}:${WLS_PASSWORD} \
    -H X-Requested-By:MyClient \
    -H Accept:application/json \
    -H Content-Type:application/json \
    -X GET ${HTTP_ADMIN_URL}/management/coherence/latest/clusters)

    print "$output"

    coherenceClusterName=$(echo $output | jq -r '.items[].clusterName')

    print "coherence Cluster Name: $coherenceClusterName"

    if [ "$coherenceClusterName" != "${COHERENCE_CLUSTER_NAME}" ];
    then
        echo "FAILURE - Coherence Cluster name verification failed"
        notifyFail
    else
        echo "SUCCESS - Coherence Cluster name verification is successful."
        notifyPass
    fi

    coherenceClusterStatus=$(echo $output | jq -r '.items[].running')

    if [ "$coherenceClusterStatus" != "true" ];
    then
        echo "FAILURE - Coherence Cluster status verification failed"
        notifyFail
    else
        echo "SUCCESS - Coherence Cluster status verification is successful."
        notifyPass
    fi

    EXPECTED_COHERENCE_CLUSTER_SIZE=$((${DEFAULT_CLUSTER_SIZE}+${DEFAULT_NUM_OF_COHERENCE_SERVERS}))
    print "Expected Coherence Cluster size: $EXPECTED_COHERENCE_CLUSTER_SIZE"

    ACTUAL_COHERENCE_CLUSTER_SIZE=$(echo $output | jq -r '.items[].clusterSize')
    print "Actual Coherence Cluster size: $ACTUAL_COHERENCE_CLUSTER_SIZE"

    if [ "${EXPECTED_COHERENCE_CLUSTER_SIZE}" != "${ACTUAL_COHERENCE_CLUSTER_SIZE}" ];
    then
        echo "FAILURE - Coherence Cluster size verification failed"
        notifyFail
    else
        echo "SUCCESS - Coherence Cluster size verification is successful."
        notifyPass
    fi


    clusterMembers=()
    output="$(echo $output | jq -r '.items[].members[]')"
    IFS=
    while read -r member;
    do
        member=$(echo $member | cut -d "(" -f2 | cut -d ")" -f1)
        member=$(echo $member | grep member | cut -d ',' -f8| cut -d':' -f2)
        clusterMembers+=($member)
    done <<< "${output}"

    print "this clusterMembers: ${clusterMembers[*]}"
    failed=false

    for ((i=1;i<=DEFAULT_CLUSTER_SIZE;i++));
    do
       expectedMemberId="${MANAGED_SERVER_PREFIX}${i}";

       if printf '%s\n' ${clusterMembers[@]} | grep -q -P "^${expectedMemberId}$"; then
            print "Member ${expectedMemberId} part of Coherence cluster"
       else
            echo "FAILURE - Coherence Cluster Member verification failed. ${expectedMemberId} not part of Coherence Cluster"
            failed=true
            break
       fi
    done

    for ((i=1;i<=DEFAULT_NUM_OF_COHERENCE_SERVERS;i++));
    do
       expectedMemberId="${COHERENCE_SERVER_PREFIX}${i}";

       if printf '%s\n' ${clusterMembers[@]} | grep -q -P "^${expectedMemberId}$"; then
            print "Member ${expectedMemberId} part of Coherence cluster"
       else
            echo "FAILURE - Coherence Cluster Member verification failed. ${expectedMemberId} not part of Coherence Cluster"            
            failed=true
            break
       fi
    done


    if [ "$failed" != "true" ];
    then
         echo "SUCCESS - Coherence Cluster Member verification successful."
         notifyPass
    else
         notifyFail
    fi

}


#main

get_param "$@"

validate_input

verifyCoherenceCluster

printTestSummary
