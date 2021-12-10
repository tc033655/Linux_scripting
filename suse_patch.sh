#!/bin/bash
# Author : Tridibesh Chakraborty
# Email : Tridibesh.Chakraborty@Wipro.com
# Purpose : This script collects the available patches on a certain date and then create commands to install them in a later date to have the unified patches installed on the server

if [ -z $1 ]; then
        DATE=`date '+%Y-%m-%d'`
else
        DATE=$1
fi

logger "$DATE : Running /usr/local/bin/suse_patch.sh to prepare custom patch installation script"
logfile=/var/log/suse_patch.log
echo "$DATE : Running /usr/local/bin/suse_patch.sh to prepare custom patch installation script" >>$logfile
echo "========================================================================================" >>$logfile
echo "Refreshing the repositories" >>$logfile
zypper ref >>$logfile
echo "Available patches till DATE : $DATE" >>$logfile
zypper -q lp --date $DATE >>$logfile
zypper -q lp --date $DATE | grep "|" |grep -v Status|cut -d "|" -f 2 >/tmp/patchlist
echo "Preparing the patch list" >>$logfile
awk -F : '{printf("%s\t ", $1)}' /tmp/patchlist >/tmp/newpatchlist
echo "Preparing the command for patching
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $logfile
echo "zypper install --type patch `cat /tmp/newpatchlist` " > /usr/local/bin/zypper_patch
cat /usr/local/bin/zypper_patch >>$logfile
chmod +x /usr/local/bin/zypper_patch
echo "Please run /usr/local/bin/zypper_patch to install the patches available on today $DATE" >>$logfile
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
========================================================================================" >>$logfile
