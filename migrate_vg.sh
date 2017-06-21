#!/bin/bash
#Purpose  : Script to migrate VGs, can be used during the SAN migration on Linux node. This is an uptime activity.
#Author   : Tridibesh Chakraborty
#Email id : t.e.chakraborty@accenture.com
#Version  : 0.1
#Date     : 28th May 2017
################################################
clear
printf "Do you want to execute this migration script [yes/no] : "
read ans

ans=`echo $ans| tr A-Z a-z`   ###Added extra
if [ "$ans" = "no" ]; then
	echo "Exiting from the script... "
	exit
elif	[ "$ans" = "yes" ]; then
	echo -e "\033[31m\033[1mYou have choose to proceed with the migration\033[0m"
	echo "Below are the present VGs on the node"
	echo "==========================================="
	vgs --all | awk '{print $1,$6}' | column -t
	echo "===========================================" 
	printf "Please type the exact VG name : "
	read VG_NAME
else
	echo "Wrong input. Please type either of "yes/no""
	exit
fi

echo -e "You have selected \033[1m$VG_NAME\033[0m for migration"
printf "Are you sure about the selection [y/n] : "
read conf

conf=`echo $conf | tr A-Z a-z` ###Added extra

if [ "$conf" = "n" ]; then
	printf "Please retype the VG name : "
	read VG_NAME
elif [ "$conf" = "y" ]; then
	echo "Proceeding with the migration"
else
	echo "Wrong input. Please type either of "y/n" "
	exit
fi
echo "==========================================="
echo "Checking the available disks on the node... Please be patient"

if [ -e /var/run/multipathd.pid ]; then
	echo "Collecting multipath devices..."
	multipath -ll | grep mpath | awk '{print $1}' >/tmp/mpaths
else
	echo "Collecting list of disks..."
	fdisk -l | grep Disk | egrep -i "sd|vd|hd"|awk '{print $2,$3,$4}' >/tmp/disks
fi

echo "Checking disk usage status..."

for DISK in `cut -d ":" -f1 /tmp/disks`
do
	ls -l $DISK* | awk '{print $10}' >/tmp/disk_details
	for disk in `cat /tmp/disk_details`
	do
		df -hTP | grep -w $disk >/dev/null
		if [ $? -eq 0 ]; then
			disk_status=used
		else
			pvs $disk >/dev/null 2>/dev/null
			if [ $? -eq 0 ]; then
				vg_name=`pvs | grep -w $disk | awk '{print $2}'`
				if [ -z $vg_name ]; then
					disk_status=free
				else
					disk_status=used
				fi
			else
				disk_status=free
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
	echo "$DISK	$DISK_SIZE" >>/tmp/free_disks
	fi
		
done	
clear
echo "=========================================
Below are the FREE disks on the node :-
========================================="
column -t /tmp/free_disks
echo "========================================="
printf "Please provide the target disk name : "
read target

if [ -e "$target"1 ]; then
	target="$target"1
elif [ -e "$target"p1 ]; then
	target="$target"p1
else
	target=$target
fi

echo -e "You have decided to migrate \033[1m$VG_NAME\033[0m to \033[31m$target\033[0m"
printf "Is it intended? [y/n] : "
read ans

case $ans in 
[yY] )

pvs | grep -w $VG_NAME | awk '{print $1,$5}' >/tmp/source_pvs
echo "Which PV you want to migrate ?"
cat /tmp/source_pvs
echo "========================================="
printf "Source PV : "
read source
;;

[nN] )

echo "Please restart the script and make proper selection... Exiting "
exit
;;

*) echo "Invalid input"
exit
;;

esac

echo "Collecting Logical Volume informations..."
pvdisplay -m $source |grep "Logical volume" | awk '{print $3}' | sort -u >/tmp/lv_details
echo -e "Extending \033[33m$VG_NAME\033[0m with the target disk \033[31m$target\033[0m..."
vgextend $VG_NAME $target
echo "Comparing Physical extent counts between source and target disk..."
source_pe=`pvdisplay $source | grep "Total PE" | awk '{print $3}'`
source_free_pe=`pvdisplay $source | grep "Free PE" | awk '{print $3}'`
source_used_pe=`expr $source_pe - $source_free_pe`
target_pe=`pvdisplay $target | grep "Total PE" | awk '{print $3}'`

if [ "$target_pe" -ge "$source_used_pe" ]; then
	echo "Starting migration.....
============================================"
	for LV in `cat /tmp/lv_details`
	do
		echo -e "Migrating \033[1m\033[35m$LV\033[0m from \033[1m\033[35m$source\033[0m to \033[1m\033[35m$target\033[0m
==========================================="
		pvmove -v -i0 -n $LV $source $target
		echo "--------------------------------------------"
	done
	echo -e "\033[32mMigration completed successfully\033[0m
***********************************************"
	vgdisplay -v $VG_NAME | egrep -i "pv name|total pe"
	echo "***********************************************"	
else
	vgreduce $VG_NAME $target
	pvremove $target
	echo -e "\033[31mYou should use a bigger disk for migration. Exiting...\033[0m"
	exit
fi

printf "Do you want to remove $source from $VG_NAME [y/n] : "
read ans

case $ans in

[yY] )
echo "Removing the disk $source from VG $VG_NAME..."
vgreduce $VG_NAME $source
pvremove $source
;;

[nN] )
echo "Leaving the disk $source inside VG $VG_NAME"
;;

esac


rm -rf /tmp/mpaths /tmp/disks /tmp/disk_details /tmp/disk_status /tmp/free_disks /tmp/source_pvs /tmp/lv_details
echo -e "\033[32mMigration completed successfully\033[0m. Please reclaim the old disk from the node"
exit


