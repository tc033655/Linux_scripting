#!/bin/bash
#Author : This script will configure the server for SAP build

echo "Hello, run this script to configure the server for SAP installation (HANA and Netweaver)
You can run completely or choose to run selected option
Options are:
=======================================
Disk
User
Permission
Software
Sapconfig
All
======================================="
printf "Please select an option : "
read option
scriptname=$0
option=`echo $option| tr '[a-z]' '[A-Z]'`
tempdir=/tmp/buildtask

if [ -e $tempdir ]; then
        echo "Temp dir is there"
else
        mkdir -p $tempdir
fi

disk ()
{
        echo "Finding disks attached to the server"
        echo "" >$tempdir/useddisk
        lsblk -d | grep -i disk >$tempdir/disks
        for disk in `cat "$tempdir"/disks | awk '{print $1}'`
        do
                size=`grep -w ^$disk $tempdir/disks | awk '{print $4}'`
                df -hTP | grep /dev/$disk >/dev/null
                if [ $? -eq 0 ]; then
                    diskuse=used
                    echo "/dev/$disk is used" >>$tempdir/useddisk
                else
                    swapon -s | grep /dev/$disk >/dev/null
                    if [ $? -eq 0 ]; then
                        diskuse=used
                        echo "/dev/$disk is used" >>$tempdir/useddisk
                    else
                        pvs | grep /dev/$disk >/dev/null
                        if [ $? -eq 0 ]; then
                            diskuse=used
                            echo "/dev/$disk is used" >>$tempdir/useddisk
                        else
                            diskuse=unused

                        fi
                    fi
                fi
                echo "/dev/$disk $size $diskuse"
        done
        echo "Volume Group name : "
        vi $tempdir/vglist
        for vgname in `cat $tempdir/vglist`
        do
        echo "Creating Volume Group : $vgname "
        printf "Disk to use : "
        read disk
        grep -w "$disk" $tempdir/useddisk >/dev/null
        if [ $? -eq 0 ]; then
            echo "$disk is in use. Please use unused disk"
            printf "Disk to use : "
            read disk
        fi

        vgcreate $vgname $disk
        printf "Logical Volume name: "
        read lvname
        printf "Type of Logical Volume [Linear/Striping] : "
        read type
        type=`echo $type| tr '[a-z]' '[A-Z]'`
        if [ $type = "STRIPING" ]; then
            printf "No of stripes : "
            read stripecount
            printf "Provide the other disks of same size as $disk (space separated) : "
            read disks
            vgextend $vgname $disks
            printf "Striping size in KB : "
            read stripesize
            printf "Do you want to use full VG size for Logical Volume [yes/no] : "
            read answer
            answer=`echo $answer | tr '[a-z]' '[A-Z]'`
            if [ $answer = "YES" ]; then
                lvcreate -l +100%FREE -i $stripecount -I "$stripesize"k -n $lvname $vgname
            else
                printf "Please provide Logical Volume Size [GB] : "
                read lvsize
                lvcreate -L +"$lvsize"G -i $stripecount -I "$stripesize"k -n $lvname $vgname
            fi
        else
            printf "Do you want to use full VG size for Logical Volume [yes/no] : "
            read answer
            answer=`echo $answer | tr '[a-z]' '[A-Z]'`
            if [ $answer = "YES" ]; then
                lvcreate -l +100%FREE -n $lvname $vgname
            else
                printf "Please provide Logical Volume Size [GB] : "
                read lvsize
                lvcreate -L +"$lvsize"G -n $lvname $vgname
            fi
        fi
        printf "Please provide the Mountpoint : "
        read mountpoint
        if [ -e $mountpoint ]; then
            printf "Type of filesystem [xfs/ext4] : "
            read fstype
            if [ $fstype = "xfs" ]; then
                mkfs.xfs -L $lvname /dev/"$vgname"/"$lvname"
                echo "/dev/$vgname/$lvname      $mountpoint     xfs     defaults 0 0" >>/etc/fstab
            elif [ $fstype = "ext4" ]; then
                mkfs.ext4 -L $lvname /dev/"$vgname"/"$lvname"
                echo "/dev/$vgname/$lvname      $mountpoint     ext4     defaults 0 0" >>/etc/fstab
            else
                echo "Please manually format the Logical volume and mount it"
            fi
        else
            mkdir -p $mountpoint
            printf "Type of filesystem [xfs/ext4] : "
            read fstype
            if [ $fstype = "xfs" ]; then
                mkfs.xfs -L $lvname /dev/"$vgname"/"$lvname"
                echo "/dev/$vgname/$lvname      $mountpoint     xfs     defaults 0 0" >>/etc/fstab
            elif [ $fstype = "ext4" ]; then
                mkfs.ext4 -L $lvname /dev/"$vgname"/"$lvname"
                echo "/dev/$vgname/$lvname      $mountpoint     ext4     defaults 0 0" >>/etc/fstab
            else
                echo "Please manually format the Logical volume and mount it"
            fi
        fi
        done
        mount -a
        df -hTP
        echo "If you want to change the ownership and permission of the mountpoints, please perform them manually"

}


user ()
{
    echo "User Names : "
    vi $tempdir/userlist
    for user in `cat $tempdir/userlist`
    do
        echo "Creating user : $user "
                printf "User ID : "
        read userid
        printf "Primary Group : "
        read pgroup
        grep $pgroup /etc/group >/dev/null
        if [ $? -eq 0 ]; then
            echo "Primary Group exists"
        else
            printf "Group ID for $pgroup : "
            read gid
            groupadd -g $gid $pgroup
        fi
        printf "Secondary Group : "
        read sgroup
        grep $sgroup /etc/group >/dev/null
        if [ $? -eq 0 ]; then
            echo "Secondary Group exists"
        else
            printf "Group ID : "
            read gid
            groupadd -g $gid $sgroup
        fi
        printf "Shell to use : "
        read usershell
        printf "Home Directory : "
        read homedir
        echo "Creating User : $user"
        useradd -m -u $userid -g $pgroup -G $sgroup -s $usershell -d $homedir $user
        passwd $user
    done

}

permission ()
{
    printf "Do you want to change Ownership and Permission [ yes/no ] : "
    read answer
    answer=`echo $answer | tr '[a-z]' '[A-Z]'`
    if [ $answer = "YES" ]; then
        printf "Directory : "
        read directory
        printf "Owner : "
        read owner
        printf "Permission : "
        read perm
        printf "Group owner : "
        read grp
        chown -R $owner:$grp $directory
        chmod -R $perm $directory
    elif [ $answer = "NO" ]; then
        echo "No change made"
    else
        echo "Please provide yes/no"
    fi

}




software ()
{
    echo "Applying updates available"
    zypper ref
    zypper up -y
    if [ $? -eq 0 ]; then
        echo "Reboot the server to apply the patches"
    else
        echo "System update failed. Please fix it and perform update manually"
        exit 1
    fi
    echo "Installing libopenssl1_0_0 & libatomic1"
    zypper in -y libopenssl1_0_0 libatomic1
    echo "Installing sapconf, saptune and UUIDD if not installed already"
    rpm -qa | egrep -i sapconf >/dev/null
    if [ $? -eq 0 ]; then
        echo "sapconf is already installed"
    else
        echo "Installing sapconf"
        zypper in -y sapconf
    fi
    rpm -qa |grep -i saptune >/dev/null
    if [ $? -eq 0 ]; then
        echo "Saptune is already installed"
    else
        echo "Installing saptune"
        zypper in -y saptune
    fi
    rpm -qa |grep -i uuidd >/dev/null
    if [ $? -eq 0 ]; then
        echo "UUID is already installed"
        systemctl enable uuidd
        systemctl restart uuidd
    else
        echo "Installing UUIDD"
        zypper in -y uuidd
        echo "Enabling UUIDD service"
        systemctl enable uuidd
        systemctl restart uuidd
    fi
    echo "If you need to install any more packages, please install them manually"
}


sapconfig ()
{
    echo "Enabling saptune"
    saptune daemon start
    saptune solution list
    printf "Which solution you want to apply [HANA/NETWEAVER or anyother (specify from above list] : "
    read solution
    saptune solution apply $solution
    saptune solution list
    echo "Configuring /dev/shm"
    printf "How much size you want to use (GB) : "
    read shmsize
    touch /usr/local/bin/shmconfig
    chmod +x /usr/local/bin/shmconfig
    echo "#!/bin/bash " >> /usr/local/bin/shmconfig
    echo "mount -o remount,size="$shmsize"G /dev/shm" >>/usr/local/bin/shmconfig
    echo '@reboot  /usr/local/bin/shmconfig' >/etc/cron.d/shmconfig
    mount -o remount,size="$shmsize"G /dev/shm
}


case "$option" in

"DISK") disk
;;
"USER") user
;;
"PERMISSION") permission
;;
"SOFTWARE") software
;;
"SAPCONFIG") sapconfig
;;
"ALL")
disk
user
permission
software
sapconfig
;;
*) echo "Please select either of options mentioned above"
;;
esac
