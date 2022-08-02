#!/bin/bash

function usage()
{
  echo "$0 <RG_NAME> <DB_NAME>"
  echo "Example: $0 rg_oracle_test myOracleDB"
  exit 1
}

function check_current_shell()
{
   if [ "${_}" == "${1}" ];
    then
       echo "Invalid command: Please use . $0 "
       echo "On Successful execution, the following environment variables will be set with Oracle DB parameters"
       echo "DB_PUBLIC_IP"
       echo "DB_PUBLIC_HOSTNAME"
       echo "DB_USERNAME"
       echo "DB_PASSWD"
       echo "DB_SID"
       echo "DB_JDBC_URL"
       exit 1
    fi
}

function validate_args()
{
    if [ $# != 2 ];
    then
      usage;
    fi

    RG_NAME="$1"
    DB_NAME="$2"

    if [[ ${DB_NAME} =~ ^[a-zA-Z]+$ ]]
    then
       n=${#DB_NAME}
       if [ $n -gt 8 ];
       then
           echo "Invalid DB_NAME DB_NAME has to be a string containing only alphabets with maximum of 8 characters"
           exit 1
       fi
    else
       echo "Invalid DB_NAME. DB_NAME has to be a string containing only alphabets with maximum of 8 characters"
       exit 1
    fi

    NEW_UUID=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 4 | head -n 1)
    DB_NAME_LC="${DB_NAME,,}"
    PUBLIC_IP="${NEW_UUID}${DB_NAME_LC}"
    SID="${DB_NAME_LC}"
}

function create_resource_group()
{
    echo "creating resource group ${RG_NAME}"
    az group create --name ${RG_NAME} --location ${LOCATION} 
}

function create_oracle_db_vm()
{
    echo "creating VM ${DB_NAME} in resource group ${RG_NAME} for setting up Oracle DB"
    az vm create \
        --resource-group ${RG_NAME} \
        --name ${DB_NAME} \
        --image ${ORACLE_DB_IMAGE} \
        --size Standard_DS2_v2 \
        --public-ip-sku Standard \
        --public-ip-address-allocation static \
        --public-ip-address-dns-name ${PUBLIC_IP} \
        --authentication-type ssh \
        --generate-ssh-keys \
        --admin-username ${VM_ADMIN_USER}

   if [ "$?" != "0" ];
   then
      echo "Database VM creation failed !!"
      exit 1
   else
      echo "Database VM Successfull !!"
   fi

}

function attach_disk_to_vm()
{
    echo "creating disk for Oracle DB ${DB_NAME}"
    az vm disk attach --name ${DISK_NAME} --new --resource-group ${RG_NAME} --size-gb 64 --sku StandardSSD_LRS --vm-name ${DB_NAME} 
}

function create_nsg_to_open_ports()
{
    echo "creating NSG rule to open port 1521 for DB: ${DB_NAME}"
    az network nsg rule create \
        --resource-group ${RG_NAME} \
        --nsg-name ${DB_NAME}NSG \
        --name allow-oracle \
        --protocol tcp \
        --priority 1001 \
        --destination-port-range ${DB_PORT}
        
    #create nsg and open port for remote connectivity
    echo "creating NSG rule to open Oracle Database Enterprise Manager Express port ${DB_EM_EXPRESS_PORT}: "
    az network nsg rule create \
        --resource-group ${RG_NAME} \
        --nsg-name ${DB_NAME}NSG \
        --name allow-oracle-EM \
        --protocol tcp \
        --priority 1002 \
        --destination-port-range ${DB_EM_EXPRESS_PORT}

    echo "wait for VM and Network configuration to complete and then connect using SSH..."
    sleep 30s
}


function get_public_ip_hostname_for_dbvm()
{
    #obtain public ip adress of database VM
    echo "Obtaining public IP Address of database VM: ${DB_NAME}"
    PUBLIC_IP_ADDRESS=$(az network public-ip show \
        --resource-group ${RG_NAME} \
        --name ${DB_NAME}PublicIP \
        --query [ipAddress] \
        --output tsv)

    PUBLIC_HOST_NAME=$(az network public-ip show \
        --resource-group ${RG_NAME} \
        --name ${DB_NAME}PublicIP \
        --query [dnsSettings.fqdn] \
        --output tsv)


    echo "PUBLIC HOST NAME: ${PUBLIC_HOST_NAME}"
    echo "Public IP Address: ${PUBLIC_IP_ADDRESS}"
}

function verify_ssh_connection_to_dbvm()
{
    echo "Configure Database by performing SSH to Database VM..."
    ssh -o "StrictHostKeyChecking no" azureuser@${PUBLIC_IP_ADDRESS} "hostname -f"

    if [ $? == 0 ];
    then
      echo "Database VM accessible over SSH "
    else
      echo "Database VM not accessible over SSH"
      exit 1
    fi
}


function configure_db_as_root()
{
    rm -f /tmp/configureORADBasRoot.sh

cat << EOF > /tmp/configureORADBasRoot.sh
    MOUNT_POINT="/u02"
    DATA_FS="oradata"
    RESULT="\$(ls -alt /dev/sdc*|head -1)"
    DISK_PATH="\$(echo "\$RESULT"|rev|cut -d' ' -f1|rev)"

    #create disk label
    parted -s \${DISK_PATH} mklabel gpt
    parted -s -a optimal \${DISK_PATH} mkpart primary 0GB 64GB

    #check the device details by printing its metadata
    parted -s \${DISK_PATH} print

    #Create a filesystem on the device partition
    FILE_SYSTEM="\${DISK_PATH}1"
    mkfs -t ext4 \${FILE_SYSTEM}

    #Create a mount point
    mkdir \${MOUNT_POINT}

    #Mount the disk
    mount \${FILE_SYSTEM} \${MOUNT_POINT}

    #change permissions on mount point
    chmod 777 \${MOUNT_POINT}

    #add the mount to fstab
    echo "\${FILE_SYSTEM}               \${MOUNT_POINT}                  ext4    defaults        0 0" >> /etc/fstab

    #update etc hosts
    echo "${PUBLIC_IP_ADDRESS} ${PUBLIC_HOST_NAME} ${DB_NAME}" >> /etc/hosts

    #update hosts file to add domin name
    sed -i 's/$/\.eastus\.cloudapp\.azure\.com &/' /etc/hostname

    #open firewall ports
    firewall-cmd --zone=public --add-port=${DB_PORT}/tcp --permanent
    firewall-cmd --zone=public --add-port=${DB_EM_EXPRESS_PORT}/tcp --permanent
    firewall-cmd --reload

EOF
    copy_and_execute_root_dbconfig
}

function configure_db_as_orauser()
{

    rm -f /tmp/configureORADBasOracleUser.sh

    cat << EOF > /tmp/configureORADBasOracleUser.sh
    #start the database listener
    lsnrctl start

    #create directory for data filesystem
    MOUNT_POINT="/u02"
    DATA_FS="oradata"
    DB_PASSWD="${DB_PASSWD}"
    SID="${SID}"
    SYS_USER="sys"
    WLS_ENG_USER="wlseng"
    WLS_ENG_PASSWD="wls123"

    DATA_FILE_PATH="\${MOUNT_POINT}/\${DATA_FS}"
    mkdir \${DATA_FILE_PATH}

    #run the database creation assistant
    nohup dbca -silent \
       -createDatabase \
       -templateName General_Purpose.dbc \
       -gdbname \${SID} \
       -sid \${SID} \
       -responseFile NO_VALUE \
       -characterSet AL32UTF8 \
       -sysPassword \${DB_PASSWD} \
       -systemPassword \${DB_PASSWD} \
       -createAsContainerDatabase false \
       -databaseType MULTIPURPOSE \
       -automaticMemoryManagement false \
       -storageType FS \
       -datafileDestination "\${DATA_FILE_PATH}" \
       -ignorePreReqs &

    counter=1
    DBCA_COMPLETE="false"

    while [  \${counter} -lt 60 ];
    do

       if [ ! -f /u01/app/oracle/cfgtoollogs/dbca/${SID}/${SID}.log ];
       then
             echo "Iteration \${counter} : dbca activity not yet started"
             counter=\$((counter+1))
             sleep 60s
       else

             cat /u01/app/oracle/cfgtoollogs/dbca/${SID}/${SID}.log | grep "DBCA_PROGRESS : 100%"
             result1="\$?"

             cat /u01/app/oracle/cfgtoollogs/dbca/${SID}/${SID}.log | grep "Database creation complete"
             result2="\$?"

             if [ "\$result1" != 0 ] && [ "\$result2" != "0" ];
             then
                echo "Iteration \${counter} :  dbca in progress"
                sleep 20s
                counter=\$((counter+1))
             else
                 echo "Iteration \${counter} :  dbca utility completed"
                 DBCA_COMPLETE="true"
                 break
             fi
       fi
    done


    if [ "\${DBCA_COMPLETE}" == "false" ];
    then
      echo "DBCA Utility failed !! Failed to create Oracle Database."
      exit 1
    else
      echo "Successfully completed execution of database creation assistant"
    fi

    export ORACLE_SID=\${SID}   
    echo "export ORACLE_SID=\${SID}" >> ~oracle/.bashrc   

    echo "exit" | sqlplus -L \${SYS_USER}/\${DB_PASSWD} as sysdba | grep Connected > /dev/null

    if [ \$? == 0 ];
    then
      echo "SUCCESS: Successfully created Oracle DB and connected to DB as system user"
    else
      echo "FAILURE: Failed to create Oracle DB and connect to DB as system user"
      exit 1
    fi

echo "creating wlseng user"

    cat << REALEND > /tmp/createWLSDBUser.sql
CREATE USER \${WLS_ENG_USER} IDENTIFIED BY \${WLS_ENG_PASSWD};
GRANT CONNECT TO \${WLS_ENG_USER};
GRANT CREATE SESSION TO \${WLS_ENG_USER};
GRANT CREATE TABLE TO \${WLS_ENG_USER};
GRANT UNLIMITED TABLESPACE TO \${WLS_ENG_USER};
GRANT CREATE PROCEDURE TO \${WLS_ENG_USER};
REALEND

echo "exit" | sqlplus -S \${SYS_USER}/\${DB_PASSWD} as sysdba @/tmp/createWLSDBUser.sql

echo "created wlseng user"

EOF
    copy_and_execute_oracle_user_dbconfig
}

function copy_and_execute_root_dbconfig()
{
    scp /tmp/configureORADBasRoot.sh azureuser@${PUBLIC_IP_ADDRESS}:/tmp/configureORADBasRoot.sh
    ssh azureuser@${PUBLIC_IP_ADDRESS} "sudo cp /tmp/configureORADBasRoot.sh /root/configureORADBasRoot.sh"
    ssh azureuser@${PUBLIC_IP_ADDRESS} "sudo chmod +x /root/configureORADBasRoot.sh"
    ssh azureuser@${PUBLIC_IP_ADDRESS} "sudo /root/configureORADBasRoot.sh"
}

function copy_and_execute_oracle_user_dbconfig()
{
    scp /tmp/configureORADBasOracleUser.sh azureuser@${PUBLIC_IP_ADDRESS}:/tmp/configureORADBasOracleUser.sh
    ssh azureuser@${PUBLIC_IP_ADDRESS} "sudo cp /tmp/configureORADBasOracleUser.sh /home/oracle/configureORADBasOracleUser.sh"
    ssh azureuser@${PUBLIC_IP_ADDRESS} "sudo chmod +x /home/oracle/configureORADBasOracleUser.sh"
    ssh azureuser@${PUBLIC_IP_ADDRESS} "sudo chown -R oracle:oinstall /home/oracle/configureORADBasOracleUser.sh"
    ssh azureuser@${PUBLIC_IP_ADDRESS} "sudo -i -u oracle /home/oracle/configureORADBasOracleUser.sh"

    if [ $? == 0 ];
    then
       echo "Azure Oracle DB configuration completed successfully"
       echo "use the following environment variables to connect to the oracle DB"
       echo "DB_PUBLIC_IP"
       echo "DB_PUBLIC_HOSTNAME"
       echo "DB_USERNAME"
       echo "DB_PASSWD"
       echo "DB_SID"
       echo "DB_JDBC_URL"
    else
       echo "Azure Oracle DB configuration failed !!"
       exit 1
    fi
}

function export_db_details_as_env_variables()
{
   export DB_PUBLIC_IP="${PUBLIC_IP_ADDRESS}"
   export DB_PUBLIC_HOSTNAME="${PUBLIC_HOST_NAME}"
   export DB_USERNAME="${WLS_ENG_USER}"
   export DB_PASSWD="${WLS_ENG_PASSWD}"
   export DB_SID="${SID}"
   export DB_PORT="${DB_PORT}"
   export DB_JDBC_URL="jdbc:oracle:thin:@//${PUBLIC_IP_ADDRESS}:${DB_PORT}/${SID}"

}

#main

check_current_shell "${0}"

LOCATION="eastus"
ORACLE_DB_IMAGE="Oracle:oracle-database-19-3:oracle-database-19-0904:latest"
VM_ADMIN_USER="azureuser"
DISK_NAME="oradata01"
DB_PORT="1521"
DB_EM_EXPRESS_PORT="5502"
DB_USERNAME="sys as sysdba"
DB_PASSWD="OraPasswd1"
WLS_ENG_USER="wlseng"
WLS_ENG_PASSWD="wls123"

validate_args "$@"

start=$(date +%s)

create_resource_group

create_oracle_db_vm

attach_disk_to_vm

create_nsg_to_open_ports

get_public_ip_hostname_for_dbvm

verify_ssh_connection_to_dbvm

configure_db_as_root

configure_db_as_orauser

export_db_details_as_env_variables

end=$(date +%s)
echo "Time taken to execute the script : $(($end-$start)) seconds"
