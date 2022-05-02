from java.io import FileInputStream
import java.lang
import os
import string

def getClusterName(username,Password,adminURL):
    try:

        print 'getting clusterName...'

        connect(userName,password,adminURL)

        domainConfig()
        serverNames = cmo.getServers()
        for server in serverNames:
            name = server.getName()
            if 'admin' in name.lower():
                    continue
            cd('/Servers/'+name)
            cluster=cmo.getCluster()
            clusterName=cluster.getName()

            if clusterName != None :
                break

        print 'clusterName: '+clusterName

        return clusterName
    except Exception,e:
        print Exception
        dumpStack()

    disconnect()


# Stop the servers in the cluster
def shutdownCluster(username,password,adminURL):
    try:
        connect(userName,password,adminURL)
        serverNames = cmo.getServers()
        for server in serverNames:
            name = server.getName()
            if 'admin' in name.lower() or 'dummy' in name.lower():
                    continue
            shutdown(name,'Server','true',1000,force='true', block='true')

        disconnect()
    except Exception, e:
        print 'Error while shutting down cluster' ,e
        dumpStack()


# Start the servers in the cluster
def startCluster(username,password,adminURL):
    try:
        connect(userName,password,adminURL)
        serverNames = cmo.getServers()
        for server in serverNames:
            name = server.getName()
            if 'admin' in name.lower() or 'dummy' in name.lower():
                    continue
            start(name,'Server')


        disconnect()
    except Exception, e:
        print 'Error while starting cluster' ,e
        dumpStack()


def restartCluster(userName,password,adminURL):

    print 'restarting cluster ...'
    shutdownCluster(username,password,adminURL)
    startCluster(username,password,adminURL)


#main

userName=sys.argv[1]
password=sys.argv[2]
adminURL=sys.argv[3]

print adminURL
print userName
print password


clusterName = getClusterName(userName,password,adminURL)
restartCluster(userName,password,adminURL)

