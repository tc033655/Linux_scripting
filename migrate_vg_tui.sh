#!/bin/bash
#Purpose  : Script to migrate VGs, can be used during the SAN migration on Linux node. This is an uptime activity. This uses the dialog command to make it as TUI tool.
#Author   : Tridibesh Chakraborty
#Email id : tridibesh.chakraborty@yahoo.com
#Version  : 1.0
#Date     : 28th May 2017
#Date     : 22nd June 2017 (added dialog for TUI support)
#Date     : 27th June 2017 (Added user details to capture and also dialog software precheck)
#Date     : 28th June 2017 (Added logging features for future reference and troubleshooting)
#Date     : 17th July 2017 (Added progress bar in LV migration dialog box)
################################################

PATH=/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin
export PATH

DATE=`date "+%d_%m_%Y_%I-%M-%S%P"`
LOGFILE=/tmp/storage_migration_$DATE.log
ERRORLOG=/tmp/storage_migration_$DATE.error

### Defining the function to get swap details ###

swap_details ()
{
while read line
do
    case "$line" in
    */dev/dm-* ) device=`echo $line | awk '{print $1}'`;
            device_trimmed=`echo "$device" | awk -F'/' '{print $3}'`;
            new_device=`cat /sys/block/$device_trimmed/dm/name`;
            line=${line/$device_trimmed/mapper\/$new_device};
            echo "$line";;          
    * ) echo "$line";;
    esac
done < /proc/swaps
}



#Checking the user details

user=`whoami`

if [ "$user" = "root" ]; then
        terminal=`tty| cut -d "/" -f3,4`
        localuser=`who -u | grep "$terminal" | awk '{print $1}'`
        logger "$localuser executed $0 on `date` from terminal $terminal"
                echo "`date` : $localuser started the script on `date` from $terminal" >$LOGFILE
else
        echo "Attention :       You need to execute the script as root"
                echo "`date` : The script need root access to execute" >$ERRORLOG
        exit
fi

clear

if [ "$localuser" = "root" ]; then
	echo "`date` : The user is directly login as root. Need to get the user details" >>$LOGFILE
	dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --inputbox "You have directly login as root. Please provide your name or email address for record purpose:" 10 60 2>/tmp/response
	localuser=`cat /tmp/response`
	echo "`date` : $localuser actually executed the script" >>$LOGFILE
fi

##Checking status for the required packages to run the script

#Checking dialog package status

echo "`date` : Checking the dialog package installation status" >>$LOGFILE
rpm -q dialog >> $LOGFILE 2>>$ERRORLOG

if [ $? = 1 ]; then
        echo "You need to install the dialog package to proceed with the script further.
To install the package please type below command:

        yum install dialog -y
"
                echo "`date` : dialog package is not installed on the node" >>$ERRORLOG
exit

else
        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "All prechecks are met. Proceeding further with the script." 30 60
                echo "`date` : dialog package is present on the node. All the prechecks are satisfied. Proceeding further with the migration" >>$LOGFILE
fi



clear

dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --yesno "\Zb\Z1Do you want to execute this migration script:\Zn" 0 0 

ans=$?
clear

if [ "$ans" = 1 ]; then
        echo "Exiting from the script... "
        echo "`date` : $localuser stopped the script execution" >>$LOGFILE
        exit
elif    [ "$ans" = 0 ]; then

#echo "You have decided to proceed with the migration!


vgs --all | awk '{print $1,$6}' | grep -v VSize |column -t > /tmp/output.temp

vg_count=`wc -l /tmp/output.temp | awk '{print $1}'`


dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --cr-wrap --menu "Below are the present VGs on the node. Please select the VG you want to migrate:" 20 50 $vg_count $(cat /tmp/output.temp) 2>/tmp/response


ans=$?
if [ "$ans" = 0 ];then
        VG_NAME=`cat /tmp/response`
else
        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --infobox "\Zb\Z1You have cancelled the operation!\Zn" 30 60
        echo "`date` : $localuser cancelled the operation @VG information dialog box." >>$LOGFILE
        exit
fi

else

        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --msgbox "You have aborted the script execution." 30 60
        echo "`date` : The script is exitted abnormally" >>$LOGFILE
        exit
fi


if [ -z "$VG_NAME" ]; then
        echo "`date` : VG name provided was zero. Reconfirming about the VG name" >>$LOGFILE
        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --inputbox "\Zb\Z1VG Name can't be empty\Zn. Please retype the VG name:" 30 60 2>/tmp/response
        VG_NAME=`cat /tmp/response`
        echo "`date` : $VG_NAME is provided for the migration" >>$LOGFILE
fi


echo "`date` : $localuser selected $VG_NAME for migration" >>$LOGFILE
dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --yesno "You have selected \Zb\Z1\Zu$VG_NAME\Zn for migration. Are you sure?" 10 60

conf=$?
if [ "$conf" = 1 ]; then


        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --inputbox "Please retype the VG name:" 30 60 2>/tmp/response
        if [ $? = 1 ]; then
                echo "`date` : $localuser cancelled the script" >>$LOGFILE
                exit
        fi
        VG_NAME=`cat /tmp/response`
        echo "`date` : $localuser modified the VG details. New selected VG is $VG_NAME" >>$LOGFILE

elif [ "$conf" = 0 ]; then

        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --infobox "Proceed with the migration on \Zb\Z2\Zu$VG_NAME\Zn" 30 60
        clear

else

        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Script execution is cancelled" 30 60
        echo "`date` : Script execution is cancelled" >>$LOGFILE
        clear
        exit

fi

echo "===========================================
`date` : Checking the available disks on the node... Please be patient" >>$LOGFILE

dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Checking the available disks on the node... This might take some time. Please be patient" 30 60


if [ -e /var/run/multipathd/multipathd.pid ]; then
        echo "`date` : Node is configured with multipath. Collecting multipath devices details" >>$LOGFILE
        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Collecting multipath devices details..." 30 60
        multipath -ll | grep mpath | awk '{print $1}' >/tmp/mpaths
	for MPATH in `cat /tmp/mpaths`
	do
		MPATH_SIZE=`lsblk | grep -w $MPATH | awk '{print $4}' | head -1`
		echo "/dev/mapper/$MPATH: "$MPATH_SIZE"B," >>/tmp/disks
	done
else
        echo "`date` : Node is configured with native disks. Collecting list of disks." >>$LOGFILE
        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Collecting list of disks details..." 30 60
        fdisk -l | grep Disk | egrep -i "sd|vd|hd"|awk '{print $2,$3,$4}' >/tmp/disks
fi

echo "`date` : Checking disk usage status." >>$LOGFILE
dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Checking disk usage status..." 30 60

for DISK in `cut -d ":" -f1 /tmp/disks`
do
        echo $DISK|grep mpath >/dev/null
	if [ $? -eq 0 ]; then
		ls -l $DISK* | awk '{print $9}' >/tmp/disk_details
	else
		ls -l $DISK* | awk '{print $10}' >/tmp/disk_details
	fi
        for disk in `cat /tmp/disk_details`
        do
                df -hTP | grep -w $disk >/dev/null
                if [ $? = 0 ]; then
                        disk_status=used
                else
                        pvs $disk >/dev/null 2>/dev/null
                        if [ $? = 0 ]; then
                                vg_name=`pvs | grep -w $disk | awk '{print $2}'`
                                if [ -z $vg_name ]; then
                                        disk_status=free
                                else
                                        disk_status=used
                                fi
                        else
                                swap_details | grep -w $disk 1>>$LOGFILE 2>>$ERRORLOG
                                if [ $? = 0 ]; then
                                        disk_status=used
                                else
                                disk_status=free
                                fi

                        fi
                fi
                if [ "$disk_status" = "free" ]; then
                        echo "$disk FREE" >>/tmp/disk_status
                else
                        echo "$disk USED" >>/tmp/disk_status
                fi
        done

        grep $DISK /tmp/disk_status | grep USED >/dev/null
        if [ $? != 0 ]; then
        DISK_SIZE=`grep -w $DISK /tmp/disks | awk '{print $2,$3}'| cut -d "," -f 1`
        echo "$DISK     $DISK_SIZE" >>/tmp/free_disks
        fi

done
clear

awk '{print $1,$2$3}' /tmp/free_disks >/tmp/response

disk_count=`wc -l /tmp/response|awk '{print $1}'`


dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --cr-wrap --menu "Below are the free disk on the node:\n" 30 50 $disk_count $(cat /tmp/response) 2>/tmp/response

if [ $? = 1 ]; then
        echo "`date` : $localuser cancelled the script" >>$LOGFILE
        exit
fi

target=`cat /tmp/response`

if [ -e "$target"1 ]; then
        target="$target"1
elif [ -e "$target"p1 ]; then
        target="$target"p1
else
        target=$target
fi

dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --yesno "You have decided to migrate \Zb\Z1\Zu$VG_NAME\Zn to disk \Zb\Z1\Zu$target\Zn . Is it intended?" 30 60
ans=$?


case $ans in 
0)
echo "`date` : $localuser decided to migrate $VG_NAME on $target" >>$LOGFILE
pvs | grep -w $VG_NAME | awk '{print $1,$5}' >/tmp/source_pvs
pv_count=`wc -l /tmp/source_pvs|awk '{print $1}'` 


dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --cr-wrap --menu "Which PV you want to migrate:\n" 30 50 $pv_count $(cat /tmp/source_pvs) 2>/tmp/response

if [ $? = 0 ]; then
source=`cat /tmp/response`
echo "`date` : $localuser selected $source as source for migration" >>$LOGFILE
fi
;;

1)

dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Please restart the script and make proper selection... Exiting" 30 60
echo "`date` : $localuser exitted the script" >>$LOGFILE
exit
;;

*) echo "`date` : Script inturpted" >>$LOGFILE
dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Script inturpted" 10 60
exit
;;

esac

echo "`date` : Collecting Logical Volume informations." >>$LOGFILE

dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Collecting Logical Volume information..." 30 60

pvdisplay -m $source |grep "Logical volume" | awk '{print $3}' | sort -u >/tmp/lv_details


dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Extending $VG_NAME with the target disk $target ..." 30 60

echo "`date` : $VG_NAME is being extended with the target disk $target" >>$LOGFILE
vgextend $VG_NAME $target >>$LOGFILE 2>>$ERRORLOG

echo "`date` : Comparing Physical extent counts between source and target disk." >>$LOGFILE

dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Comparing Physical extent counts between source and target disk..." 30 60

source_pe=`pvdisplay $source | grep "Total PE" | awk '{print $3}'`
source_free_pe=`pvdisplay $source | grep "Free PE" | awk '{print $3}'`
source_used_pe=`expr $source_pe - $source_free_pe`
target_pe=`pvdisplay $target | grep "Total PE" | awk '{print $3}'`

if [ "$target_pe" -ge "$source_used_pe" ]; then

        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --infobox "\Zb\Z2Starting migration...\Zn" 10 60
        echo "`date` : Starting migration for VG $VG_NAME" >>$LOGFILE
(       lv_count=`wc -l /tmp/lv_details | awk '{print $1}'`
        progress=0
        for LV in `cat /tmp/lv_details`
        do
echo "`date` : Migrating $LV from $source to $target
===========================================" >>$LOGFILE
                
                pct=$(( $progress * 100 / $lv_count ))
                echo "XXX"
                echo "Migrating $LV from $source to $target"
                pvmove -v -i0 -n $LV $source $target 1>>$LOGFILE 2>>$ERRORLOG
                echo "XXX"
                echo "$pct"
                progress=$((progress+1))
                [ $progress -gt $lv_count ] && break
                sleep 3

echo "--------------------------------------------" >>$LOGFILE
        done
)| dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --gauge "Wait please...Starting data migration..." 10 60 0
echo "`date` : Migration completed successfully
***********************************************" >>$LOGFILE
dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --infobox "\Zb\Z2Migration completed successfully\Zn" 5 60
echo "PV usage on $VG_NAME post migration:-" >/tmp/response
echo "***********************************************"  >>/tmp/response
        vgdisplay -v $VG_NAME | egrep -i "pv name|total pe" >>/tmp/response
        echo "***********************************************"  >>/tmp/response
        cat /tmp/response >>$LOGFILE
else
        echo "Error : Target disk $target is smaller than Source disk $source. Please use a bigger disk and retriegger the migration" >>$ERRORLOG
        echo "`date` : Aborting the migration due to smaller target disk disk. Will remove the target disk from the VG and delete the PV header." >>$LOGFILE
        vgreduce $VG_NAME $target >>$LOGFILE 2>>$ERRORLOG
        pvremove $target >>$LOGFILE 2>>$ERRORLOG
        dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --msgbox "\Zb\Z1You should use a bigger disk for migration\Zn" 5 60
        exit
fi


dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --yesno "Do you want to remove the \Zb\Z1\Zu$source\Zn from \Zb\Z1\Zu$VG_NAME\Zn?" 10 60
ans=$?
case $ans in

0)
echo "`date` : $localuser decided to remove the old disk $source from VG $VG_NAME post migration" >>$LOGFILE
dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Removing the disk $source from VG $VG_NAME" 5 60
vgreduce $VG_NAME $source >>$LOGFILE 2>>$ERRORLOG
pvremove $source >>$LOGFILE 2>>$ERRORLOG
;;

1)
echo "`date` : Leaving the disk $source inside VG $VG_NAME for future use" >>$LOGFILE
dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Leaving the disk $source attached in VG $VG_NAME" 10 60
;;

esac

echo "`date` : Cleaning up the temporary files." >>$LOGFILE
dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --infobox "Cleanning up temporary files..." 5 60
rm -rf /tmp/mpaths /tmp/disks /tmp/disk_details /tmp/disk_status /tmp/free_disks /tmp/source_pvs /tmp/lv_details /tmp/response >>$LOGFILE 2>>$ERRORLOG
dialog --title "Automated Storage migration v1.1" --backtitle "Automated Storage migration:" --colors --msgbox "\Zb\Z2Migration completed successfully\Zn. Please reclaim the old disk from the node" 10 60
echo "`date` : Migration completed successfully. Please reclaim the old disk $source from the node.
*********************  COMPLETED  ********************* " >>$LOGFILE
exit


