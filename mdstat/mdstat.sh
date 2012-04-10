#!/bin/sh

# Mail Delivery Statistic Tool
# Main Scrip
#
# wangzheng.gz@gmail.com
#
# 
# 

# =====================
# Configuration Section
# =====================

CONF_FILE=mdstat.conf

# Load configuration file
[ -r $CONF_FILE ] && . $CONF_FILE

# Prepare the options
# The working directory of the script, default is "/PATH/TO/CURRENT/DIR/tmp"
WORKING_DIR=${WORKING_DIR:-"tmp"}

# The stat days rotated, default is "15" days
STAT_DAYS=${STAT_DAYS:-"15"}

# The sendemail agent script location, default is located at "/PATH/TO/CURRENT/DIR/sendEmail"
STAT_SEMA=${STAT_RCVER:-"./sendEmail"}

# The mail server (SMTP Server) used to send the result, default is send via "localhost"
STAT_SMTP=${STAT_RCVER:-"localhost"}

# The mail sender of the result, default is send as "localhost@localdomain"
STAT_SENDER=${STAT_SENDER:-"localhost@localdomain"}

# The mail receiver of the result, multiple receiver should be splitted by a space (" "), default is send to "localhost@localdomain"
STAT_RCVER=${STAT_RCVER:-"localhost@localdomain"}

# The mail subjuct of the result, including server IP address is recommended, default is "MDStat Result"
STAT_SUBJ=${STAT_RCVER:-"MDStat Result"}

# =====================
# Preprocessing Section
# =====================

# Useful variables
LOG_DIR=$WORKING_DIR/log
LOG_ALL=$LOG_DIR/log_all.log
LOG_ORG=$LOG_DIR/log_org.log
LOG_FAL=$LOG_DIR/log_fal.log
STAT_RESULT=$WORKING_DIR/result.html
LOG_DATE=`date -d "1 day ago" "+%b %e"`
LOGFILE_DATE=`date -d "1 day ago" "+%Y-%m-%d"`
LOG_RESULT=$WORKING_DIR/$LOGFILE_DATE.log

[ -ne $LOG_DIR ] && mkdir $LOG_DIR

# Preparing the mail delivery log
cat /var/log/maillog* > $LOG_ALL
grep $LOG_DATE $LOG_ALL > $LOG_ORG
grep "failure" $LOG_ORG | awk '{print $10}' > $LOG_FAL

# ================
# Counting Section
# ================

# Useful variables
NUM_TOTAL=0
NUM_SUCCESS=0
NUM_FAILURE=0
NUM_FAIL_HOST=0
NUM_FAIL_MBOX=0
NUM_FAIL_SPAM=0
NUM_FAIL_MISC=0
NUM_FAIL_USER=0
NUM_TOTAL_NOT_FAIL_USER=0
NUM_RATE_SUCCESS=0
NUM_RATE_SUCCESS_NOT_FAIL_USER=0

# Counting
NUM_TOTAL=`egrep -c "(success|failure)" $LOG_ORG`
NUM_FAILURE=`egrep -c . $LOG_FAL`
NUM_SUCCESS=$[$NUM_TOTAL-$NUM_FAILURE]

NUM_FAIL_HOST=`egrep -c "(#5.4.4|#5.4.6|#4.4.3|#4.4.1|#5.1.2)" $LOG_FAL`
NUM_FAIL_MBOX=`egrep -c "Remote_host_said:_(550|450|554|511)_" $LOG_FAL`
NUM_FAIL_SPAM=`egrep -c "Remote_host_said:_(451|553)_" $LOG_FAL`
NUM_FAIL_MISC=$[$NUM_FAILURE-$NUM_FAIL_HOST-$NUM_FAIL_MBOX-$NUM_FAIL_SPAM]

NUM_FAIL_USER=$[$NUM_FAIL_HOST+$NUM_FAIL_MBOX]
NUM_TOTAL_NOT_FAIL_USER=$[$NUM_TOTAL-$NUM_FAIL_USER]

NUM_RATE_SUCCESS=`echo "scale=3;$NUM_SUCCESS/$NUM_TOTAL*100" | bc`
NUM_RATE_SUCCESS_NOT_FAIL_USER=`echo "scale=3;$NUM_SUCCESS/$NUM_TOTAL_NOT_FAIL_USER*100" | bc`

# =================
# Reporting Section
# =================

# Log to daily result file
echo "$NUM_TOTAL $NUM_SUCCESS $NUM_FAILURE $NUM_FAIL_USER $NUM_FAIL_SPAM $NUM_FAIL_MISC $NUM_RATE_SUCCESS $NUM_RATE_SUCCESS_NOT_FAIL_USER" > $LOG_RESULT

# Log to HTML report
echo "<html>" > $STAT_RESULT
echo "<TABLE style="FONT-SIZE: 9pt" borderColor=#c0c0c0 cellSpacing=0 cellPadding=3 width=500 border=1>" >> $STAT_RESULT
echo "  <TBODY>" >> $STAT_RESULT
echo "  <TR>" >> $STAT_RESULT
echo "    <TD width=100 bgColor=#000080><FONT color=#ffffff><B>日期</B></FONT></TD>" >> $STAT_RESULT
echo "    <TD width=100 bgColor=#000080><FONT color=#ffffff><B>总数</B></FONT></TD>" >> $STAT_RESULT
echo "    <TD width=100 bgColor=#000080><FONT color=#ffffff><B>成功</B></FONT></TD>" >> $STAT_RESULT
echo "    <TD width=100 bgColor=#000080><FONT color=#ffffff><B>总失败数</B></FONT></TD>" >> $STAT_RESULT
echo "    <TD width=100 bgColor=#000080><FONT color=#ffffff><B>收件人错误</B></FONT></TD>" >> $STAT_RESULT
echo "    <TD width=100 bgColor=#000080><FONT color=#ffffff><B>被阻止</B></FONT></TD>" >> $STAT_RESULT
echo "    <TD width=100 bgColor=#000080><FONT color=#ffffff><B>其他错误</B></FONT></TD>" >> $STAT_RESULT
echo "    <TD width=100 bgColor=#000080><FONT color=#ffffff><B>成功率</B></FONT></TD>" >> $STAT_RESULT
echo "    <TD width=100 bgColor=#000080><FONT color=#ffffff><B>不计算收件人错误的成功率</B></FONT></TD>" >> $STAT_RESULT
echo "  </TR>" >> $STAT_RESULT

LOG_ROTATE=1
while
	[ $LOG_ROTATE -le STAT_DAYS ]
do
  LOGFILE_DATE=`date -d "$LOG_ROTATE day ago" "+%Y-%m-%d"`
	echo "  <TR>" >> $STAT_RESULT
	awk '{for (i=1;i<=NF;i++) {printf "    <TD>"; printf $i; printf "</TD>\n";}}' $LOG_RESULT >> $STAT_RESULT
	echo "  </TR>" >> $STAT_RESULT
	LOG_ROTATE=$[$LOG_ROTATE+1]
done

echo " </TBODY></TABLE>" >> $STAT_RESULT
echo "注：收件人错误包括无效的邮箱地址以及无效的后缀。其他错误包括空间满等小概率错误。" >> $STAT_RESULT
echo "</html>" >> $STAT_RESULT

# ====================
# Notification Section
# ====================

$STAT_SEMA -f $STAT_SENDER -t $STAT_RCVER -u $STAT_SUBJ -s STAT_SMTP -o message-file=$STAT_RESULT -o message-charset=gb2312


# ======================
# Postprecessing Section
# ======================

# Cleen-up
LOGFILE_DATE=`date -d "$STAT_DAYS+1 day ago" "+%Y-%m-%d"`
rm -rf $LOG_RESULT
rm -rf $LOG_DIR/log*.log
