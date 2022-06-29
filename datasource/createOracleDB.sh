#!/bin/bash

function usage()
{
  echo "$0 <RG_NAME> <DB_NAME>"
  echo "Example: $0 rg_oracle_test myOracleDB"
  exit 1
}

function validate_args()
{
    if [ $# != 2 ];
    then
      usage;
    fi

    RG_NAME="$1"
    DB_NAME="$2"

    NEW_UUID=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 4 | head -n 1)
    DB_NAME_LC="${DB_NAME,,}"
    PUBLIC_IP="${NEW_UUID}${DB_NAME_LC}"
}

function create_resource_group()
{
    echo "creating resource group ${RG_NAME}"
    az group create --name ${RG_NAME} --location ${LOCATION} 
}

function create_oracle_db_vm()
{
    echo "creating VM ${DB_NAME} in resource group ${RG_NAME} for setting up Oracle DB"
    RESULT=$(az vm create \
        --resource-group ${RG_NAME} \
        --name ${DB_NAME} \
        --image Oracle:oracle-database-19-3:oracle-database-19-0904:latest \
        --size Standard_DS2_v2 \
        --admin-username ${VM_ADMIN_USER} \
        --generate-ssh-keys \
        --public-ip-address-allocation static \
        --public-ip-address-dns-name ${PUBLIC_IP})
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
        --destination-port-range 1521
        
    #create nsg and open port for remote connectivity
    echo "creating NSG rule to open port 5502 for DB: ${DB_NAME}"
    az network nsg rule create \
        --resource-group ${RG_NAME} \
        --nsg-name ${DB_NAME}NSG \
        --name allow-oracle-EM \
        --protocol tcp \
        --priority 1002 \
        --destination-port-range 5502

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
    firewall-cmd --zone=public --add-port=1521/tcp --permanent
    firewall-cmd --zone=public --add-port=5502/tcp --permanent
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
    DB_PASSWD="OraPasswd1"
    SID="oratest1"
    SYS_USER="sys"
    DATA_FILE_PATH="\${MOUNT_POINT}/\${DATA_FS}"
    mkdir \${DATA_FILE_PATH}

    #run the database creation assistant
    dbca -silent \
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
       -ignorePreReqs

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
       echo "use the following parameters to connect to the oracle DB"
       echo "jdbc:oracle:thin:@//${PUBLIC_IP_ADDRESS}:1521/${SID}"
       echo "user: sys as sysdba"
       echo "password: OraPasswd1"
    else
       echo "Azure Oracle DB configuration failed !!"
       exit 1
    fi
}

#main

LOCATION="eastus"
VM_ADMIN_USER="azureuser"
DISK_NAME="oradata01"
SID="oratest1"

validate_args "$@"

create_resource_group

create_oracle_db_vm

attach_disk_to_vm

create_nsg_to_open_ports

get_public_ip_hostname_for_dbvm

verify_ssh_connection_to_dbvm

configure_db_as_root

configure_db_as_orauser
