# This script does WLSPatch testing


usage() { echo "Usage: $0 GITHUB_REPOSITORY GIT_USER GIT_TOKEN DEPLOY_OFFER GIT_USER_EMAIL RESOURCE_GROUP_NAME \
				SKU_VERSION PARAMETERS_FILE_PATH RUN_TESTS TEST_INPUT_FILE ADDITIONAL_DEPLOYMENT_PARAMETERS ADDITIONAL_TEST_PARAMETERS
  GITHUB_REPOSITORY                : WebLogic azure repository. https://github.com/<user>/weblogic-azure.git
  DEPLOY_OFFER                     : admin,cluster,dynamic
  PARAMETERS_FILE_PATH             : json file name available under arm-wls-patch-test/offer_parameters
  RUN_TESTS                        : Test names which are directories under arm-wls-patch-test.
                                     For example basic,adminonly,cluster
  TEST_INPUT_FILE                  : .props file available under arm-wls-patch-test/test_input
  ADDITIONAL_DEPLOYMENT_PARAMETERS : Overriding parameters for offer with name and value pair.
  ADDITIONAL_TEST_PARAMETERS       : Overriding test parameters with name and value pair . "   1>&2; exit 1; }



function cleanup()
{
	cd $WORK_DIRECTORY
	if [ -d weblogic-azure ];
	then
		rm -rf weblogic-azure
	fi
	
}


function validateArguments()
{
	if [ -z "${GITHUB_REPOSITORY}" ] || [ -z "${GIT_USER}" ] || [ -z "${GIT_TOKEN}" ] || [ -z "${GIT_USER_EMAIL}" ] || [ -z "${DEPLOY_OFFER}" ] || [ -z "${RESOURCE_GROUP_NAME}" ] || [ -z "${SKU_VERSION}" ] || [ -z "${PARAMETERS_FILE_PATH}" ] || [ -z "${RUN_TESTS}" ] || [ -z "${TEST_INPUT_FILE}" ]; then
		usage
	fi
}

read GITHUB_REPOSITORY GIT_USER GIT_TOKEN DEPLOY_OFFER GIT_USER_EMAIL RESOURCE_GROUP_NAME SKU_VERSION PARAMETERS_FILE_PATH RUN_TESTS TEST_INPUT_FILE ADDITIONAL_DEPLOYMENT_PARAMETERS ADDITIONAL_TEST_PARAMETERS
echo "$GITHUB_REPOSITORY $GIT_USER $GIT_TOKEN $DEPLOY_OFFER $GIT_USER_EMAIL $RESOURCE_GROUP_NAME $SKU_VERSION $PARAMETERS_FILE_PATH $RUN_TESTS $TEST_INPUT_FILE $ADDITIONAL_DEPLOYMENT_PARAMETERS $ADDITIONAL_TEST_PARAMETERS"

currentDir=`pwd`
source ${currentDir}/utils/deploy_test_utils.sh
#Script execution starts here
CURRENT_PATH=`pwd`
WORK_DIRECTORY=$CURRENT_PATH/repository
date=`date +%F-%s`
TEST_BRANCH_NAME="testpatch-$date"
REQ_GIT_VERSION=2.3
WLS_TEST_GIT_REPOSITORY="https://github.com/sanjaymantoor/arm-wls-patch-test.git"
TEST_RAW_MAIN_TEMPLATE_URL="https://raw.githubusercontent.com/sanjaymantoor/arm-wls-patch-test/master/test_templates/arm/mainTemplate.json"
TEST_ARTIFACT_LOCATION="https://raw.githubusercontent.com/sanjaymantoor/arm-wls-patch-test/master/test_templates/arm/"
LOCATION=eastus

mkdir -p $WORK_DIRECTORY

git config --global core.longpaths true
git config --global user.email "${GIT_USER_EMAIL}"
git config --global user.name "${GIT_USER}"

validateArguments
gitVersionCheck $REQ_GIT_VERSION
jqVersionCheck
cleanup
# Update template files skuUrnVersion with supplied SKU_VERSION
createNewGitBranch $GITHUB_REPOSITORY $WORK_DIRECTORY $TEST_BRANCH_NAME $GIT_USER $GIT_TOKEN $GIT_USER_EMAIL $SKU_VERSION
azureCLICheck

case "${DEPLOY_OFFER}" in 
	"admin")
			RAW_MAIN_TEMPLATE_URL="https://raw.githubusercontent.com/$GIT_USER/weblogic-azure/$TEST_BRANCH_NAME/weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/mainTemplate.json"
			deployAdminOffer $PARAMETERS_FILE_PATH $RESOURCE_GROUP_NAME $RAW_MAIN_TEMPLATE_URL $LOCATION $SKU_VERSION $ADDITIONAL_DEPLOYMENT_PARAMETERS
			TEST_ADMIN_OFFER_SCRIPT="runAdminOfferTest.sh" 
			testOffer $WLS_TEST_GIT_REPOSITORY $TEST_RAW_MAIN_TEMPLATE_URL $RESOURCE_GROUP_NAME $RUN_TESTS $TEST_INPUT_FILE $TEST_ADMIN_OFFER_SCRIPT $LOCATION $TEST_ARTIFACT_LOCATION $ADDITIONAL_TEST_PARAMETERS 
			;;
	
	"cluster")
			RAW_MAIN_TEMPLATE_URL="https://raw.githubusercontent.com/$GIT_USER/weblogic-azure/$TEST_BRANCH_NAME/weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/mainTemplate.json"
			deployClusterOffer $PARAMETERS_FILE_PATH $RESOURCE_GROUP_NAME $RAW_MAIN_TEMPLATE_URL $LOCATION $SKU_VERSION $ADDITIONAL_DEPLOYMENT_PARAMETERS
			TEST_CLUSTER_OFFER_SCRIPT="runClusterOfferTest.sh"
			testOffer $WLS_TEST_GIT_REPOSITORY $TEST_RAW_MAIN_TEMPLATE_URL $RESOURCE_GROUP_NAME $RUN_TESTS $TEST_INPUT_FILE $TEST_CLUSTER_OFFER_SCRIPT $LOCATION $TEST_ARTIFACT_LOCATION $ADDITIONAL_TEST_PARAMETERS
			;;
			
	"dynamic")
			RAW_MAIN_TEMPLATE_URL="https://raw.githubusercontent.com/$GIT_USER/weblogic-azure/$TEST_BRANCH_NAME/weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/mainTemplate.json"
			deployClusterOffer $PARAMETERS_FILE_PATH $RESOURCE_GROUP_NAME $RAW_MAIN_TEMPLATE_URL $LOCATION $SKU_VERSION $ADDITIONAL_DEPLOYMENT_PARAMETERS
			TEST_CLUSTER_OFFER_SCRIPT="runClusterOfferTest.sh"
			testOffer $WLS_TEST_GIT_REPOSITORY $TEST_RAW_MAIN_TEMPLATE_URL $RESOURCE_GROUP_NAME $RUN_TESTS $TEST_INPUT_FILE $TEST_CLUSTER_OFFER_SCRIPT $LOCATION $TEST_ARTIFACT_LOCATION $ADDITIONAL_TEST_PARAMETERS
			;;
esac


deleteGitBranch $WORK_DIRECTORY $GIT_USER $GIT_TOKEN $TEST_BRANCH_NAME
cleanup

