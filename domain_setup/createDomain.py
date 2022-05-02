import os
import sys
import time
from os.path import exists
from sys import argv


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


def printdomain():
        print '------------------------------'
        print "Properties Information"
        print '------------------------------'
        for key, val in _dict.iteritems():
                print key,"=>",val

def export_properties():

        global mwhome
        global wlshome
        global domainroot
        global approot
        global domainName
        global domain_username
        global domain_password
        global adminPort
        global adminAddress
        global adminPortSSL
        global adminMachine
        global machines
        global servers
        global clusters
        global nmPort
        global nmHost

        mwhome = _dict.get('mwhome')
        wlshome = _dict.get('wlshome')
        domainroot = _dict.get('domainroot')
        approot = _dict.get('approot')
        domainName = _dict.get('domain_name')
        domain_username = _dict.get('domain_username')
        domain_password = _dict.get('domain_password')

        adminPort = _dict.get("admin.port")
        adminAddress = _dict.get("admin.address")
        adminPortSSL = _dict.get("admin.port.ssl")
        #adminMachine = _dict.get("admin.machine")

        machines = _dict.get("machines").split(',')
        servers = _dict.get("managedservers").split(',')
        clusters = _dict.get("clusters").split(',')

        nmPort=_dict.get("nmPort")
        nmHost=_dict.get("nmHost")

def read_template():
        # Load the template. Versions < 12.2
        try:
                readTemplate(wlshome + '/common/templates/wls/wls.jar')
        except:
                print "Error Reading the Template",wlshome
                print "Dumpstack: \n -------------- \n",dumpStack()
                sys.exit(2)

def create_machine():
        try:
                cd('/')
                for machine in machines:
                        print "Creating a New Machine with the following Configuration"
                        machine_name=_dict.get(machine+'.Name')
                        print 'Machine Name :',machine_name
                        create(machine_name,'UnixMachine')
                        cd('/UnixMachine/' + machine_name)
                        create(machine_name, 'NodeManager')
                        cd('NodeManager/' + machine_name)
                        set('ListenAddress', nmHost)


        except Exception,e:
                print e
                print "Creating Machine failed",machine
                print "Dumpstack: \n -------------- \n",dumpStack()
                sys.exit(2)

def create_admin():
        try:
                print "\nCreating AdminServer with the following Configuraiton"
                cd('/Security/base_domain/User/' + domain_username)
                cmo.setPassword(domain_password)
                cd('/Server/AdminServer')
                cmo.setName('AdminServer')
                cmo.setListenPort(int(adminPort))
                cmo.setListenAddress(adminAddress)
                print "\tAdminServer ListenPort:",adminPort
                print "\tAdminServer Listenaddress:",adminAddress
                print "\tAdminServer SSLListenPort:",adminPortSSL

                create('AdminServer','SSL')
                cd('SSL/AdminServer')
                set('Enabled', 'True')
                set('ListenPort', int(adminPortSSL))

        except:
                print "Error while creating AdminServer"
                print "Dumpstack: \n -------------- \n",dumpStack()

def create_managedserver():
        try:
                cd ('/')
                for server in servers:
                        MSN = _dict.get(server+'.Name')
                        MSP = _dict.get(server+'.port')
                        MSA = _dict.get(server+'.address')
                        MSM = _dict.get(server+'.machine')
                        print "\nCreating A New Managed Server with following Configuration"
                        print "\tServerName:",MSN
                        print "\tServer ListenPort:",MSP
                        print "\tServer ListenAddress:",MSA
                        sobj = create(MSN,'Server')
                        sobj.setName(MSN)
                        sobj.setListenPort(int(MSP))
                        sobj.setListenAddress(MSA)

                        #sobj.setMachine(MSM)
        except:
                print "Error While Creating ManagedServer",server
                print "Dumpstack: \n -------------- \n",dumpStack()


def create_clusters():
        try:
                cd ('/')
                for cluster in clusters:
                        CN = _dict.get(cluster+'.Name')
                        cobj = create(CN,'Cluster')
                        print "\nCreating a New Cluster with the following Configuration"
                        print "\tClusterName",CN
        except:
                print "Error while Creating Cluster",cluster
                print "Dumpstack: \n -------------- \n",dumpStack()
                sys.exit(2)

def commit_writedomain():
        try:
                # If the domain already exists, overwrite the domain
                setOption('OverwriteDomain', 'true')

                setOption('ServerStartMode','prod')
                setOption('AppDir', approot + '/' + domainName)

                writeDomain(domainroot + '/' + domainName)
                closeTemplate()

        except:
                print "ERROR: commit_writedomain Failed"
                print "Dumpstack: \n -------------- \n",dumpStack()
                undo('false','y')
                stopEdit()
                exit()

def print_withformat(title):
        print "\n-----------------------------------------------------\n",title,"\n-----------------------------------------------------"

def print_somelines():
        print "-----------------------------------------------------"

def print_domainsummary():
        print "DomainName:",domainName
        print "DomainUserName:",domain_username
        print "DomainPassword: ****************"
        print "DomainDirectory:",domainroot
        print "ApplicationRoot:",approot

def start_AdminServer():
        try:
                global managementurl
                managementurl = "t3://"+adminAddress+":"+adminPort
                global AdminServerDir
                AdminServerDir = domainroot+"/"+domainName+"/servers/AdminServer"
                global AdminServerLogDir
                AdminServerLog = AdminServerDir+"/logs/AdminServer.log"
                global DomainDir
                DomainDir = domainroot+"/"+domainName

                print_somelines()
                print "\nStarting Server with following Params"
                print_somelines()
                print "DomainDir",DomainDir
                print "managementurl",managementurl
                print_somelines()

                print "\nRedirecting Startup Logs to",AdminServerLog
                startServer('AdminServer',domainName,managementurl,domain_username,domain_password,DomainDir,'true',60000,serverLog=AdminServerLog)

                print "AdminServer has been successfully Started"
        except:
                print "ERROR: Unable to Start AdminServer"
                print "Dumpstack: \n -------------- \n",dumpStack()

def restart_AdminServer():
        try:
                global managementurl
                managementurl = "t3://"+adminAddress+":"+adminPort
                global AdminServerDir
                AdminServerDir = domainroot+"/"+domainName+"/servers/AdminServer"
                global AdminServerLogDir
                AdminServerLog = AdminServerDir+"/logs/AdminServer.log"
                global DomainDir
                DomainDir = domainroot+"/"+domainName

                print "\nRedirecting Startup Logs to",AdminServerLog
                shutdown('AdminServer','Server',force='true',block='true')
                print 'AdminServer shutdown successfully'
                startServer('AdminServer',domainName,managementurl,domain_username,domain_password,DomainDir,'true',60000,serverLog=AdminServerLog)
                print "AdminServer has been successfully restarted"
        except:
                print "ERROR: Unable to Start AdminServer"
                print "Dumpstack: \n -------------- \n",dumpStack()

def connect_online():
        try:
                global managementurl
                managementurl = "t3://"+adminAddress+":"+adminPort
                print "\nConnecting to AdminServer with managementurl",managementurl
                connect(domain_username,domain_password,managementurl)
                print "\nSuccessfully Connected to AdminServer!!."

        except:
                print "ERROR: Unable to Connect to AdminServer"
                sys.exit(2)

def acquire_edit_session():
        edit()
        startEdit()

def save_activate_session():
        save()
        activate()

def Enable_wlst_log_redirection():
        #wlst output redirect to a logfile
        redirect('./wlst_execution.log','false')

def Stop_wlst_log_redirection():
        stopRedirect()
def map_machines():
        #try:
        acquire_edit_session()
        for machine in machines:
                 print "Starting to map resources to the machine ",machine
                 instances = _dict.get(machine+".instances")
                 #print "INST",instances
                 if len(instances) > 1:
                        instances = instances.split(',')
                        for instance in instances:
                                if instance == "admin":
                                        instname = "AdminServer"
                                else:
                                        instname = _dict.get(instance+".Name")
                                #print "What is the instname",instname
                                cd ('/Servers/'+instname)
                                #print "WHARE AM I",pwd()
                                machine_name=_dict.get(machine+'.Name')
                                mbean_name='/Machines/'+machine_name
                                #print "What is Machine MBEAN",mbean_name
                                cmo.setMachine(getMBean(mbean_name))
                 else:
                                instname = _dict.get(instances+".Name")
                                #print "What is the instname",instname
                                cd ('/Servers/'+instname)
                                #print "WHARE AM I",pwd()
                                machine_name=_dict.get(machine+'.Name')
                                mbean_name='/Machines/'+machine_name
                                cmo.setMachine(getMBean(mbean_name))
        save_activate_session()

def map_clusters():
        #try:
        acquire_edit_session()
        for cluster in clusters:
                 print "\nStarting to map resources to the cluster ",cluster
                 members = _dict.get(cluster+".members")
                 #print "members",members
                 if len(members) > 1:
                        members = members.split(',')
                        for member in members:
                                if member == "admin":
                                        membername = "AdminServer"
                                else:
                                        membername = _dict.get(member+".Name")
                                #print "What is the memberName",membername
                                cd ('/Servers/'+membername)
                                #print "WHARE AM I",pwd()
                                cluster_name=_dict.get(cluster+'.Name')
                                mbean_name='/Clusters/'+cluster_name
                                #print "What is Cluster MBEAN",mbean_name
                                cmo.setCluster(getMBean(mbean_name))
                 else:
                                membername = _dict.get(member+".Name")
                                #print "What is the memberName",membername
                                cd ('/Servers/'+membername)
                                #print "WHARE AM I",pwd()
                                cluster_name=_dict.get(cluster+'.Name')
                                mbean_name='../../Clusters/'+cluster_name
                                cmo.setCluster(getMBean(mbean_name))
        save_activate_session()
        #except:
                #print "Machine Creation Failed"


def start_NodeManager():
        startNodeManager(verbose='true',NodeManagerHome=domainroot + '/' + domainName+ '/nodemanager', ListenPort=nmPort, ListenAddress=nmHost, jvmArgs='-Xms512m,-Xmx1024m')

def start_ManagedServers():
        connect_online()
        for cluster in clusters:
                 print "\nStarting to map resources to the cluster ",cluster
                 members = _dict.get(cluster+".members")
                 #print "members",members
                 if len(members) > 1:
                        members = members.split(',')
                        for member in members:
                                if member == "admin":
                                        continue
                                else:
                                        membername = _dict.get(member+".Name")
                                start(membername,'Server')
                 else:
                                membername = _dict.get(member+".Name")
                                start(membername,'Server')


def run_main():
    global _dict
    _dict={};
    Enable_wlst_log_redirection()
    print "Start of the script Execution >>"
    print "Parsing the properties file..."
    parsefile()
    print "Exporting the Properties to variables.."
    export_properties()
    print "Creating Domain from Domain Template..."
    read_template()
    print_withformat("Creating Machines")
    create_machine()
    print_somelines()
    print_withformat("Creating AdminServer")
    create_admin()
    print_somelines()
    print_withformat("Creating ManagedServers")
    create_managedserver()
    print_somelines()
    print_withformat("Creating Clusters")
    create_clusters()
    print_somelines()
    print "\nCommit and Saving the Domain"
    commit_writedomain()
    print_withformat("Domain Summary")
    print_domainsummary()
    print_somelines()
    print("Starting the AdminServer")
    start_AdminServer()
    connect_online()
    map_machines()
    map_clusters()
    start_NodeManager()
    start_ManagedServers()
    restart_AdminServer()
    print "End of Script Execution << \nGood Bye!"
    Stop_wlst_log_redirection()
    sys.exit(0)

if __name__ != "__main__":
    run_main()


if __name__ == "__main__":
    print "This script has to be executed with weblogic WLST"
    run_main()


