import sys
import os
import re
import time
from os.path import exists
from sys import argv
from java.lang import System

#Python Script to manage applications in weblogic server.
#This script takes input from command line and executes it.
#It can be used to check status,stop,start,deploy,undeploy of applications in weblogic server using weblogic wlst tool.
#Company: TechPaste Solutions
import getopt
#========================
#Usage Section
#========================

def get_script_path():
        return os.path.dirname(os.path.realpath(sys.argv[0]))

def parsefile():
        propfile = get_script_path()+"/domain.properties"
        if exists(propfile):
                global fo
                fo = open(propfile, 'r+')
                lines = fo.readlines()
                for line in lines:
                        #print line.rstrip()
                        if "=" in line:
                                line = line.rstrip()
                                key = line.split('=')[0]
                                value = line.split('=')[1]
                                _dict[key]=value

def export_properties():
        global _dict
        global approot
        global domain_username
        global domain_password
        global adminPort
        global adminAddress
        global adminPortSSL
        global clusters
        global deploymentName
        global deploymentTarget
        global deploymentFile

        approot = _dict.get('approot')
        domain_username = _dict.get('domain_username')
        domain_password = _dict.get('domain_password')

        adminPort = _dict.get("admin.port")
        adminAddress = _dict.get("admin.address")
        adminPortSSL = _dict.get("admin.port.ssl")

        clusters = _dict.get("clusters").split(',')

        deploymentName = _dict.get("deployment.name")
        deploymentFile = _dict.get("deployment.file")
        deploymentTarget = _dict.get("deployment.target")

#========================
#Connect To Admin Server
#========================

def connect_online():
        try:
                global managementurl
                managementurl = "t3://"+adminAddress+":"+adminPort
                print "\nConnecting to AdminServer with managementurl",managementurl
                connect(domain_username,domain_password,managementurl)
                print "\nSuccessfully Connected to AdminServer!!."

        except Exception,e:
                print e
                print "ERROR: Unable to Connect to AdminServer"
                dumpStack()
                sys.exit(2)

#========================
#Checking Application Status Section
#========================

def appstatus(deploymentName, deploymentTarget):

	try:
		domainRuntime()
		cd('domainRuntime:/AppRuntimeStateRuntime/AppRuntimeStateRuntime')
		currentState = cmo.getCurrentState(deploymentName, deploymentTarget)
		return currentState
	except:
		print 'Error in getting current status of ' +deploymentName+ '\n'
		exit()
#========================
#Application undeployment Section
#========================

def undeployApplication():

	try:
		print 'stopping and undeploying ..' +deploymentName+ '\n'
		stopApplication(deploymentName, targets=deploymentTarget)
		undeploy(deploymentName, targets=deploymentTarget)
	except:
		print 'Error during the stop and undeployment of ' +deploymentName+ '\n'
#========================
#Applications deployment Section
#========================

def deployApplication():

	try:
		print 'Deploying the application ' +deploymentName+ '\n'
		deploy(deploymentName,get_script_path()+'/'+deploymentFile,targets=deploymentTarget,upload='true')
		startApplication(deploymentName)
	except:
		print 'Error during the deployment of ' +deploymentName+ '\n'
		exit()

#========================
#Main Control Block For Operations
#========================

def deployUndeployMain():

		appList = re.findall(deploymentName, ls('/AppDeployments'))
		if len(appList) >= 1:
    			print 'Application'+deploymentName+' Found on server '+deploymentTarget+', undeploying application..'
			print '=============================================================================='
			print 'Application Already Exists, Undeploying...'
			print '=============================================================================='
    			undeployApplication()
			print '=============================================================================='
    			print 'Redeploying Application '+deploymentName+' on'+deploymentTarget+' server...'
			print '=============================================================================='
			deployApplication()
	   	else:
			print '=============================================================================='
			print 'No application with same name...'
    			print 'Deploying Application '+deploymentName+' on'+deploymentTarget+' server...'
			print '=============================================================================='
			deployApplication()


def run_main(): 
    global _dict
    _dict={};
    parsefile()
    export_properties()
    connect_online()
    print '=============================================================================='
    print 'Starting Deployment...'
    print '=============================================================================='
    deployUndeployMain()
    print '=============================================================================='
    print 'Execution completed...'
    print '=============================================================================='
    disconnect()
    exit()

if __name__ != "__main__":
    run_main()


if __name__ == "__main__":
    print "This script has to be executed with weblogic WLST"
    run_main()


