#!/bin/bash
# Purpose : Checking SAN path status for hostlist
# Author: Tridibesh Chakraborty
#Version: 1.0
HOSTLIST=/export/incident/SAN_PATH_CHECK/bin/hostlist
TMP_DIR=/export/incident/SAN_PATH_CHECK/logs

#HOSTLIST=/home/tc033655/scripts/hostlist
#TMP_DIR=/home/tc033655/hostlist_check
if [ -d $TMP_DIR ]; then
echo "Temp Directory is present"
else
mkdir -p $TMP_DIR
fi

LOGDIR=$TMP_DIR/`date "+%d_%m_%Y"`
FINAL_DIR=$TMP_DIR/final
FINAL_OUT=$FINAL_DIR/SAN_PATH_CHECK_REPORT_`date "+%d_%m_%Y"`.out
TEMP_OUT=$LOGDIR/temp.out


if [ -d $LOGDIR ]; then
echo "Log directory present"
else
mkdir -p $LOGDIR
fi
>$TEMP_OUT
>$FINAL_OUT
echo "<HTML>
<HEAD>
<TITLE>
SAN Path Check Report Generation status
</TITLE>
</HEAD>
<BODY>
<table border=1 style=width:80%>
<caption> Linux SAN Path Check Report(Corporate)</caption>
<tr>
<th align="center">HOSTNAME</th>
<th align="center">Total Paths </th>
<th align="center"> Intact Paths </th>
<th align="center"> Failed Paths </th>
</tr>">>$FINAL_OUT


for HOST in `cat $HOSTLIST`
do
        /export/incident/SAN_PATH_CHECK/bin/san_path_check.sh $HOST 1>"$LOGDIR"/"$HOST".log 2>>$LOGDIR/error.log
        TOTAL_PATH=`grep TOTAL "$LOGDIR"/"$HOST".log | cut -d ":" -f 2`
        FAULTY_PATH=`egrep "FAULTY PATHS" "$LOGDIR"/"$HOST".log | cut -d ":" -f 2`
        INTACT_PATH=`grep INTACT "$LOGDIR"/"$HOST".log | cut -d ":" -f 2`
        #printf "%-30s %-15s %-15s %-10s\n" $HOST $TOTAL_PATH $INTACT_PATH $FAULTY_PATH >>$TEMP_OUT

echo "
<tr>
<td align="center">$HOST</td>
<td align="center">$TOTAL_PATH</td>
<td align="center">$INTACT_PATH</td>
<td align="center">$FAULTY_PATH</td>
</tr> " >>$FINAL_OUT

done

mailx -s "$(echo -e "LINUX MultiPath Check Reporter: `date "+%d_%m_%Y"`\nContent-type: text/html")" tridi.etce@gmail.com <$FINAL_OUT
