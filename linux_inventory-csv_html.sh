#!/bin/bash
#Author         : Tridibesh Chakraborty
#Email          : t.e.chakraborty@accenture.com
#Version        : 0.5
#Date           : 26th June 2017
#Date        	: 7th September 2017 (Added support to run the script via sudo account)
#Date           : 22nd September 2017 (Modified the backup file details column).
#Date           : 25th September 2017 (Added the mount point and local disk details in CSV)
#Date           : 6th October 2017 (Added the multipath device details in csv)
#Purpose        : This script can be used to collect the inventory details about the server


PATH=/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin
export PATH


printf "Please provide the hostfile : "
read hostfile
TEMP=/tmp/Inventory
if [ -e "$TEMP" ]; then
	OUTPUT=/tmp/Inventory/linux_inventory.csv
	HTML_OUT=/tmp/Inventory/linux_inventory.html
else
	mkdir $TEMP
	OUTPUT=/tmp/Inventory/linux_inventory.csv
	HTML_OUT=/tmp/Inventory/linux_inventory.html
fi

echo "HOSTNAME,DOMAIN,UPTIME,KERNEL VERSION,OS RELEASE,SERIAL NUMBER,MANUFACTURER,PRODUCT,CPU,CPU COUNT,LOGICAL CORES,MEMORY,SWAP,CONFIGURED IPs,DEFAULT GATEWAY, NWInterfaceCount,ROOT DISK,DISKCOUNT,TOTAL DISK SIZE,LocalDisks,MpathCount,MpathDisks,MountDetails,InstalledDB,DBStatus,NetworkShare,NWShareCount,DetailsInventory & BackupFile" >$OUTPUT

### HTML formatting output
echo '
<!DOCTYPE html>
<html>

<head>
<title> LINUX INVENTORY </title>
</head>

<body>
<p style="color:blue;" > Linux Inventory Collection </p>

<table border="1" style="width:100%;text-align:center;">
<tr style="background-color:grey;">
<th> HOSTNAME </th>
<th> DOMAIN </th>
<th> UPTIME </th>
<th> KERNEL VERSION </th>
<th> OS RELEASE </th>
<th> SERIAL NUMBER </th>
<th> MANUFACTURER </th>
<th> PRODUCT </th>
<th> CPU </th>
<th> CPU COUNT </th>
<th> LOGICAL CORES </th>
<th> MEMORY </th>
<th> SWAP </th>
<th> CONFIGURED IPs </th>
<th> DEFAULT GATEWAY </th>
<th>  NWInterfaceCount </th>
<th> ROOT DISK </th>
<th> DISKCOUNT </th>
<th> TOTAL DISK SIZE </th>
<th> LocalDisks </th>
<th> MpathCount </th>
<th> MpathDisks </th>
<th> MountDetails </th>
<th> InstalledDB </th>
<th> DBStatus </th>
<th> NetworkShare </th>
<th> NWShareCount </th>
<th> DetailsInventory & BackupFile </th>
</tr>

' > $HTML_OUT


for HOST in `cat $hostfile`
do
        ping -c 5 $HOST
        if [ $? -eq 0 ]; then
                PING_STATUS=Yes
        else
                PING_STATUS=No
                echo "Server is not reachable. Skipping $HOST from inventory collection"
				echo "$HOST not reachable" >>/tmp/Inventory/not_reachable
        fi

        if [ "$PING_STATUS" = "Yes" ]; then
                echo "Server is reachable. Proceeding with the inventory collection. You may need to enter root/sudo account password multiple times. Also you need to accept the RSA tokens for the target servers while running the script"
				mkdir -p /tmp/Inventory/"$HOST"_inventory/
				printf "Please provide the Admin account name : "
				read admin
                scp inventory.sh "$admin"@"$HOST":/tmp/
                ssh "$admin"@"$HOST" sudo /tmp/inventory.sh 
                #ssh "$admin"@"$HOST" sudo cat /tmp/inventory/inventory.csv >>$OUTPUT
                #ssh "$admin"@"$HOST" sudo cat /tmp/inventory/inventory.html >> $HTML_OUT
		scp "$admin"@"$HOST":"/tmp/inventory/*_inventory.txt /tmp/backup/*_backup.tar /tmp/inventory/inventory.csv /tmp/inventory/inventory.html" /tmp/Inventory/"$HOST"_inventory/
		#cat /tmp/inventory/inventory.csv >>$OUTPUT
		#cat /tmp/inventory/inventory.html >>$HTML_OUT
		cat /tmp/Inventory/"$HOST"_inventory/inventory.csv >>$OUTPUT
		cat /tmp/Inventory/"$HOST"_inventory/inventory.html >>$HTML_OUT
		
        fi
		tar -cvf /tmp/Inventory/"$HOST"_inventory.tar /tmp/Inventory/"$HOST"_inventory/
		#rm -rf /tmp/Inventory/"$HOST"_inventory/
done        
            
echo "
</table>
</body>
</html> " >>$HTML_OUT
