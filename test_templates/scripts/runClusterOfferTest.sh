function usage() { echo "Usage: sh runAdminOfferTest.sh <<< 'basic,adminonly,datasource' testpropertyfile testgithubrepourl" 1>&2; exit 1; }

read testScenarios testInputFileName testArtifactRepo

sudo yum install -y git jq

sudo mkdir -p /u01/wlstest
sudo chown -R oracle:oracle /u01/wlstest
cd /u01/wlstest

rm -rf /u01/wlstest/*
echo runuser -l oracle -c "cd /u01/wlstest ; git clone $testArtifactRepo"
runuser -l oracle -c "cd /u01/wlstest ; git clone $testArtifactRepo"
testWorkDir=/u01/wlstest/arm-wls-test

cd $testWorkDir
 
testInputFileName=$testWorkDir/test_input/$testInputFileName
echo "================ PATCHING DETAILS =================="
source $testInputFileName
runuser -l oracle -c "cd ${WLS_HOME}/../OPatch;./opatch lsinventory"
echo "====================================================" 


IFS=',' testLists=( $testScenarios )
for test in ${testLists[*]}
do
	case "${test}" in
	"basic")
			echo "Executing basic tests"
			echo "sh $testWorkDir/basic/basic_test.sh -i $testInputFileName"
			sudo sh $testWorkDir/basic/basic_test.sh -i $testInputFileName > ${test}.log 2>&1
			;;
	"adminonly")
			echo "Executing adminonly tests"
			echo "sh $testWorkDir/adminonly/admin_test.sh -i $testInputFileName"
			sudo sh $testWorkDir/adminonly/admin_test.sh -i $testInputFileName > ${test}.log 2>&1
			;;
	"cluster")
			echo "Executing cluster tests"
			echo "sh $testWorkDir/cluster/cluster_test.sh -i $testInputFileName"
			sudo sh $testWorkDir/cluster/cluster_test.sh -i $testInputFileName > ${test}.log 2>&1
			;;
	"datasource")
			echo "Executing datasource tests"
			echo "sh $testWorkDir/datasource/datasource_test.sh -i $testInputFileName"
			sudo sh $testWorkDir/datasource/datasource_test.sh -i $testInputFileName > ${test}.log 2>&1
			;;
	"ssl-customcert")
			echo "Executing ssl with custom certificates"
			echo "sh $testWorkDir/ssl/ssl_test.sh -i $testInputFileName -o CERT_TYPE=CUSTOMCERT"
			sudo sh $testWorkDir/ssl/ssl_test.sh -i $testInputFileName -o CERT_TYPE=CUSTOMCERT > ${test}.log 2>&1
			;;
	"ssl-democert")
			echo "Executing ssl with demo certificates"
			echo "sh $testWorkDir/ssl/ssl_test.sh -i $testInputFileName -o CERT_TYPE=DEMOCERT"
			sudo sh $testWorkDir/ssl/ssl_test.sh -i $testInputFileName -o CERT_TYPE=DEMOCERT > ${test}.log 2>&1
			;;
	"security")
			echo "Executing security tests"
			echo "sh $testWorkDir/security/security_test.sh  -i $testInputFileName"
			sudo sh $testWorkDir/security/security_test.sh  -i $testInputFileName > ${test}.log 2>&1
			;;
	*)
			usage
			;;
	esac
	
  echo "================ ${test} Execution Details ================ " >> summary.log
  cat ${test}.log | grep "FAILURE" >> summary.log
  cat ${test}.log | grep "TEST EXECUTION SUMMARY" >> summary.log
  cat ${test}.log | grep "++" >> summary.log
  cat ${test}.log | grep "NO OF TEST PASSED:" >> summary.log
  cat ${test}.log | grep "NO OF TEST FAILED:" >> summary.log
	
done 

echo "============================"
cat summary.log
echo "============================"
cat summary.log | grep "FAILURE"
if [ $? == 0 ]; then
	echo "---------------------"
	echo "| SOME TESTS FAILED |"
	echo "---------------------" 
	exit 1
else
	echo "---------------------"
	echo "| ALL TESTS PASSED  |"
	echo "---------------------"
	exit 0
fi