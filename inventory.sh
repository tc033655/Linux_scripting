#!/bin/bash
#Author : Tridibesh Chakraborty
#Email ID : t.e.chakraborty@accenture.com
#Version : 0.5
#Date : 28/07/2017
#Date : 22nd September 2017 ## Added path variables and also rectified the network interface counts
#Date : 25th September 2017 ## Added the mount point and local disk details in CSV
#Date : 5th October 2017    ## Added the multipath disks
#Date : 17th April 2019     ## Modified the script for Suse

PATH=/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin
export PATH

mkdir /tmp/inventory/

HOSTNAME=`hostname -s`
DOMAIN=`hostname -d`
if [ -e $DOMAIN ]; then
    DOMAIN=NotAssigned
fi

UPTIME=`uptime | awk '{print $3,$4}'|cut -d "," -f 1`

DETAILS=/tmp/inventory/"$HOSTNAME"_inventory.txt
>$DETAILS

#IP_ADDRESS=`hostname -i`
#ALL_IP=`hostname -I`


#Collecting network interfaces details
#ls -l /sys/class/net/ | grep -v lo | awk '{print $9}' >/tmp/inventory/nw_interfaces
ls -l /sys/class/net/ | egrep -v "lo|sit|vir" | awk '{print $9}' | sed '/^\s*$/d' >/tmp/inventory/nw_interfaces
IF_COUNT=`wc -l /tmp/inventory/nw_interfaces | awk '{print $1}'`
echo "Network interfaces details:
====================================================" >>$DETAILS

for NW_INTERFACE in `cat /tmp/inventory/nw_interfaces`
do
        ifconfig 1>/dev/null 2>/dev/null
        if [ $? -eq 0 ]; then
            IF_IP=`ifconfig $NW_INTERFACE | grep -w inet | awk '{print $2}'`
            if [ -e $IF_IP ]; then
                IF_IP=NotAssigned
            fi
            NETMASK=`ifconfig $NW_INTERFACE |grep netmask | awk '{print $4}'`
            if [ -e $NETMASK ]; then
                NETMASK=`ifconfig $NW_INTERFACE | grep Mask | cut -d ":" -f 4`
            fi
            MAC=`ifconfig $NW_INTERFACE | grep ether | awk '{print $2}'`
            if [ -e $MAC ]; then
                MAC=`ifconfig $NW_INTERFACE | grep HWaddr  | awk '{print $5}'`
            fi
            echo "$NW_INTERFACE : $MAC : $IF_IP" >>$DETAILS
            echo "$NW_INTERFACE : $MAC : $IF_IP" >>/tmp/inventory/ip_details
        else
            IF_IP=`ip addr show $NW_INTERFACE | grep -w inet | awk '{print $2}'|cut -d "/" -f 1`
            if [ -e $IF_IP ]; then
                IF_IP=NotAssigned
            fi
            NETMASK=`ip addr show $NW_INTERFACE | grep -w inet | awk '{print $2}'|cut -d "/" -f 2`
            MAC=`ip addr show $NW_INTERFACE|grep ether | awk '{print $2}'`
            echo "$NW_INTERFACE : $MAC : $IF_IP" >>$DETAILS
            echo "$NW_INTERFACE : $MAC : $IF_IP" >>/tmp/inventory/ip_details
        fi
done
IPDETAILS=`tr '\n' ' ' </tmp/inventory/ip_details`

netstat -rn 1>/dev/null 2>/dev/null
if [ $? -eq 0 ]; then
    DEF_ROUTE=`netstat -rn | grep -w UG | awk '{print $2}'`
    echo "====================================================
    Routing table
    ====================================================" >>$DETAILS
    netstat -rn >>$DETAILS
else
    DEF_ROUTE=`ip route | grep default | awk '{print $3}' | head -1`
    echo "====================================================
Routing table
====================================================" >>$DETAILS
    ip route >>$DETAILS
fi

`df -hTP |grep -v tmpfs| awk '{print $7,$3,$4}' | column -t` >>$DETAILS
ROOT_DISK_SIZE=`df -hTP | grep -w "/" | awk '{print $3}'`

df -hTP / | grep mapper | grep -v mpath >/dev/null

if [ $? -eq 1 ]; then
        df -hTP / | grep mapper >/dev/null
        if [ $? -eq 0 ]; then
            
                rootlv=`df -hTP |grep -w "/" | awk '{print $1}' | cut -d "-" -f 2`
                ROOTDISK=`pvs --segments -o+lv_name | grep -w $rootlv | awk '{print $1}'`
        else
                ROOTDISK=`df -hTP |grep -w "/" | awk '{print $1}'`
        fi
else
        ROOTDISK=`df -hTP |grep -w "/" | awk '{print $1}'`
fi

echo "====================================================
Local disk details:
====================================================" >>$DETAILS
fdisk -l | egrep -i "/dev/sd|/dev/hd|/dev/xvd|/dev/vd" | grep Disk|awk '{print $2,$3,$4}' >>$DETAILS
LOCALDISKS=`fdisk -l | egrep -i "/dev/sd|/dev/hd|/dev/xvd|/dev/vd" | grep Disk|awk '{print $2,$3,$4}' | tr ',\n' ' '`

### Collcting SAN disk details
echo "====================================================
SAN disk details:
====================================================" >>$DETAILS
ps -ef | grep multipathd >/dev/null
if [ $? -eq 0 ]; then
multipath -ll >/tmp/mpath.out
grep "dm-" /tmp/mpath.out |awk '{print $1}' >/tmp/mpaths
MPATHCOUNT=`wc -l /tmp/mpaths | awk '{print $1}'`

for MPATH in `cat /tmp/mpaths`
do
LUNID=`grep -w $MPATH /tmp/mpath.out | awk '{print $2}'`
SIZE=`grep -A 1 -w $MPATH /tmp/mpath.out |grep size | cut -d "=" -f 2 | cut -d "]" -f 1`
echo "$MPATH : $LUNID : $SIZE" >>$DETAILS
echo "$MPATH : $SIZE" >>/tmp/mpath_out
MPATHDISK=`cat /tmp/mpath_out | tr '\n' ' '`
done

else
echo "NOMPATH :NOLUN : ZERO" >>$DETAILS
MPATHDISK="NOMPATH : ZERO"
fi


echo "====================================================
Mount point details:
====================================================" >>$DETAILS
df -hTP >>$DETAILS

MOUNTDETAILS=`df -hTP |egrep -v "Type|tmpfs"| awk '{print $1,$2,$7,$3,$4}' |tr '\n' ':'`

fdisk -l | egrep -i "/dev/sd|/dev/hd|/dev/xvd|/dev/vd" | grep Disk|awk '{print $2,$3,$4}' | cut -d "," -f 1 >/tmp/localdisk

diskcount=`wc -l /tmp/localdisk | awk '{print $1}'`
>/tmp/disk.out
for dsk in `cat /tmp/localdisk | cut -d ":" -f 1` 
do
	dsksize=`grep -w $dsk /tmp/localdisk | cut -d ":" -f 2`
	unit=`echo $dsksize | awk '{print $2}'`
	if [ "$unit" = "GB" ]; then 
		size=`echo $dsksize | awk '{print $1*1024}'`
	elif [ "$unit" = "GiB" ]; then
		size=`echo $dsksize | awk '{print $1*1024}'`
	elif [ "$unit" = "TiB" ]; then
		size=`echo $dsksize | awk '{print $1*1024*1024}'`		
	elif [ "$unit" = "TB" ]; then
		size=`echo $dsksize | awk '{print $1*1024*1024}'`
	else
		size=`echo $dsksize | awk '{print $1}'`
	fi
	echo "$dsk $size" >>/tmp/disk.out	
done
totalsize=`cat /tmp/disk.out | awk '{total +=$2}END{print total/1024}'`	



echo "====================================================
Physical volume details:
====================================================" >>$DETAILS

pvs | awk '{print $1,$2,$5}' | column -t >>$DETAILS
echo "====================================================
Volume Group details:
====================================================" >>$DETAILS

vgs | awk '{print $1,$6,$7}' | column -t >>$DETAILS
echo "====================================================
Logical Volume Details:
====================================================" >>$DETAILS

lvs|awk '{print $1,$2,$4}'|column -t >>$DETAILS

pvs --segments -o+lv_name | awk '{print $1,$2,$5,$9}' | column -t >/tmp/pv_lv
echo "PV VG PSize lv SIZE USED MOUNTPOINT" >/tmp/diskusage
grep -vw LV /tmp/pv_lv >> /tmp/diskusage
for LV in `cat /tmp/pv_lv| awk '{print $4}'`
do

df -hTP | grep -w $LV >/dev/null
if [ $? -eq 0 ]; then
LV_size=`df -hTP | grep $LV | awk '{print $3}'`
used=`df -hTP | grep $LV | awk '{print $4}'`
mountpoint=`df -hTP | grep $LV | awk '{print $7}'`

else 
LV_size=`lvs | grep -w $LV | awk '{print $4}'`
used=Unknown
mountpoint=NotMounted
fi

sed -i -e "s@$LV@$LV $LV_size $used $mountpoint@g" /tmp/diskusage
done
echo "====================================================
PhysicalVolume -> VolumeGroup -> LogicalVolume ->Mountpoint
====================================================" >>$DETAILS
column -t /tmp/diskusage >>$DETAILS


PHY_CPU_COUNT=`cat /proc/cpuinfo | grep "physical id" | sort -u | wc -l`
CPU_CORE_COUNTS=`grep -c processor /proc/cpuinfo`
CPU_MODEL=`grep "model name" /proc/cpuinfo | cut -d ":" -f 2 | sort -u`

MEMORY=`free -m | grep "Mem:"| awk '{print $2}'`MB
SWAP=`free -m |grep Swap | awk '{print $2}'`MB

KERNEL=`uname -r`

if [ -f /etc/redhat-release ]; then
    OS_Version=`cat /etc/redhat-release`
else
    OS_Version=`grep PRETTY_NAME /etc/os-release  | cut -d "=" -f 2`
fi
    
#if [ $? -eq 1 ]; then
#OS_Version=`cat /etc/issue`
#fi

dmidecode 1>/dev/null 2>/dev/null
if [ $? -eq 0 ]; then
    SERIAL=`/usr/sbin/dmidecode -t system | grep Serial | cut -d ":" -f 2`
    MANUFACTURER=`/usr/sbin/dmidecode -t system | grep Manufacturer | cut -d ":" -f 2| tr ',' ' '`
    PRODUCT=`/usr/sbin/dmidecode -t system | grep Product|cut -d ":" -f 2`
else    
    SERIAL=NotFound
    MANUFACTURER=NotFound
    PRODUCT=NotFound
fi

echo "====================================================
Running Systemd Services details
====================================================" >>$DETAILS

systemctl list-units | egrep -i "running|DESCRIPTION" >>$DETAILS

echo "====================================================
Running init Services details:
====================================================" >>$DETAILS
chkconfig --list | grep -w "3:on" >>$DETAILS
echo "====================================================" >>$DETAILS

ps -ef | grep -E "pmon|tnslsnr" |grep -v grep &> /dev/null
if [ $? -eq 0 ]; then
	DB_STATUS=YES
	DB=ORACLE

else
	rpm -qa | egrep -i "mysql|mariadb" >/dev/null
	if [ $? -eq 0 ]; then
		ps -ef | grep -i mysql | grep -v grep &> /dev/null

		if [ $? -eq 0 ]; then
			DB_STATUS=YES
			DB=MYSQL/MARIADB
		else
			DB_STATUS=NO
			DB=MYSQL/MARIADB
		fi
	else
		DB=NO
		DB_STATUS=NOTINSTALLED
	fi
fi

mount | egrep -i "nfs|cifs" &>/dev/null
if [ $? -eq 0 ]; then
	NW_SHARE=YES
	NWSHARECOUNT=`mount | egrep -c "nfs|cifs" | wc -l`
else
	NW_SHARE=NO
	NWSHARECOUNT=NIL
fi	

echo "$HOSTNAME, $DOMAIN, $UPTIME,  $KERNEL, $OS_Version, $SERIAL, $MANUFACTURER, $PRODUCT, $CPU_MODEL, $PHY_CPU_COUNT, $CPU_CORE_COUNTS, $MEMORY, $SWAP, $IPDETAILS, $DEF_ROUTE, $IF_COUNT, $ROOTDISK : $ROOT_DISK_SIZE, $diskcount, $totalsize GB, $LOCALDISKS, $MPATHCOUNT, $MPATHDISK, $MOUNTDETAILS, $DB, $DB_STATUS, $NW_SHARE, $NWSHARECOUNT, /tmp/Inventory/"$HOSTNAME"_inventory.tar" >/tmp/inventory/inventory.csv


echo "
<tr>
<td> $HOSTNAME </td>
<td> $DOMAIN </td>
<td> $UPTIME </td>
<td> $KERNEL </td>
<td> $OS_Version </td>
<td> $SERIAL </td>
<td> $MANUFACTURER </td>
<td> $PRODUCT </td>
<td> $CPU_MODEL </td>
<td> $PHY_CPU_COUNT </td>
<td> $CPU_CORE_COUNTS </td>
<td> $MEMORY </td>
<td> $SWAP </td>
<td> $IPDETAILS </td>
<td> $DEF_ROUTE </td>
<td> $IF_COUNT </td>
<td> $ROOTDISK : $ROOT_DISK_SIZE </td>
<td> $diskcount </td>
<td> $totalsize GB </td>
<td> $LOCALDISKS </td>
<td> $MPATHCOUNT </td>
<td> $MPATHDISK </td>
<td> $MOUNTDETAILS </td>
<td> $DB </td>
<td> $DB_STATUS </td>
<td> $NW_SHARE </td>
<td> $NWSHARECOUNT </td>
<td> /tmp/Inventory/"$HOSTNAME"_inventory.tar </td>
</tr> 
" >/tmp/inventory/inventory.html



echo "Collecting important files..."

mkdir /tmp/backup/
chmod -R 777 /tmp/inventory
chmod -R 777 /tmp/backup
sysctl -a >/tmp/kernel_parameters.out
tar -cvf /tmp/backup/"$HOSTNAME"_backup.tar $DETAILS /etc/passwd /etc/fstab /etc/shadow /etc/group /etc/exports /etc/hosts /tmp/kernel_parameters.out /etc/sudoers

echo "Cleaning up unnecessary temporary files..."
rm -rf /tmp/inventory/ip_details /tmp/inventory/nw_interfaces
