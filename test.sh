#/usr/bin/bash
#
#set -x
###################################################################
#Script Name  : Server_health_status.sh
#Description  :
#Args           :
#Author         : Rajendra Kumar
#Email          :
###################################################################
#
DATE=$(date +%d_%m_%Y_%H_%M_%S)
REPORT=/tmp/health_status.log
EMAIL="abc@example.com"
MYNETINFO="Server Health Check Report"


#Declare the threshold of below resources
CPU_WARN=75
LOAD_WARN=8.0
DISK_WARN=90
RAM_WARN=10
TOP_PROCESSES=10

##don't Edit below code
######################################


## main ##
##############################################

Main(){
  rhostname=`hostname`

  ruptime=`uptime`
  if $(echo $ruptime | grep -E "min|days" >/dev/null); then
    x=$(echo $ruptime | awk '{ print $3 $4}')
  else
    x=$(echo $ruptime | sed s/,//g| awk '{ print $3 " (hh:mm)"}')
  fi
  ruptime="$x"

  rload="$(uptime |awk -F'average:' '{ print $2}')"
  x="$(echo $rload | sed s/,//g | awk '{ print $2}')"
  y="$(echo "$x >= $LOAD_WARN" | bc)"
  [ "$y" == "1" ] && rload="$RED $rload (High) $NOC" || rload="$GREEN $rload (Ok) $NOC"

  rclock="$(date +"%r")"
  rtotalprocess="$(ps axue | grep -vE "^USER|grep|ps" | wc -l)"


  ##Disk Report
  rfs_threshold="$(df -hT | grep -vE "^Filesystem|shm|devtmpfs|tmpfs" \
  | awk '{print $6}'|tr -d '%' > /tmp/health_disk_report)"

  rfs="$( df -hT | grep -vE "^Filesystem|shm|devtmpfs|tmpfs" )"


  ##Memory Report
  TOTALMEM=`free -m | head -2 | tail -1| awk '{print $2}'`
  TOTALBC=`echo "scale=2;if($TOTALMEM<1024 && $TOTALMEM > 0) print 0;$TOTALMEM/1024"| bc -l`
  USEDMEM=`free -m | head -2 | tail -1| awk '{print $3}'`
  USEDBC=`echo "scale=2;if($USEDMEM<1024 && $USEDMEM > 0) print 0;$USEDMEM/1024"|bc -l`
  FREEMEM=`free -m | head -2 | tail -1| awk '{print $4}'`
  FREEBC=`echo "scale=2;if($FREEMEM<1024 && $FREEMEM > 0) print 0;$FREEMEM/1024"|bc -l`
  TOTALSWAP=`free -m | tail -1| awk '{print $2}'`
  TOTALSBC=`echo "scale=2;if($TOTALSWAP<1024 && $TOTALSWAP > 0) print 0;$TOTALSWAP/1024"| bc -l`
  USEDSWAP=`free -m | tail -1| awk '{print $3}'`
  USEDSBC=`echo "scale=2;if($USEDSWAP<1024 && $USEDSWAP > 0) print 0;$USEDSWAP/1024"|bc -l`
  FREESWAP=`free -m |  tail -1| awk '{print $4}'`
  FREESBC=`echo "scale=2;if($FREESWAP<1024 && $FREESWAP > 0) print 0;$FREESWAP/1024"|bc -l`
  RAM_SWAP_TITLE=`echo -e "Total  Used  Free %Free"`
  RAM_REPORT=`echo -e "${TOTALBC}G  ${USEDBC}G  ${FREEBC}G  $(($FREEMEM * 100 / $TOTALMEM  ))%"`
  SWAP_REPORT=`echo -e "${TOTALSBC}G  ${USEDSBC}G  ${FREESBC}G  $(($FREESWAP * 100/$TOTALSWAP ))%"`
  RAM_USED=$(($FREEMEM * 100/$TOTALMEM  ))

  if [[ $RAM_USED > $RAM_WARN ]]
  then
  echo "$RAM_USED" > /tmp/health_ram_report
  fi

  ###CPU Report
  CPU_USE=`sar -P ALL 1 2 |grep 'Average.*all' |awk -F" " '{print 100.0 - $NF}'`
  if [[ $CPU_USE > $CPU_WARN ]]
  then
  echo "$CPU_LOAD" > /tmp/health_cpu_report
  fi




  echo "Hostname: $rhostname"
  echo "Time: $rclock"
  echo "Uptime: $ruptime "
  echo "Load avarage: $rload "
  echo " "
  echo "Total running process: $rtotalprocess"
  echo " "
  echo "Disk Status:"
  echo "$rfs"

  echo " "
  echo "RAM Status:"
  echo "$RAM_SWAP_TITLE "
  echo " $RAM_REPORT  "

  echo " "
  echo "SWAP Status: "
  echo " $RAM_SWAP_TITLE "
  echo " $SWAP_REPORT  "

  echo " "
  echo "CPU Status: "
  echo " Used CPU: $CPU_USE%   "
  echo " "

}

Main |tee -a $REPORT

if [ -e /tmp/health_cpu_report ]
then
for i in `cat /tmp/health_cpu_report`
do
  if [ $i -gt $CPU_WARN ]
  then
    MAIL_SENT=1
    TITLE="$( echo "Top 15 process are consuing more CPU")"
    echo $TITLE | tee -a $REPORT
    TOP_PROCESS_CPU="$(ps -eo pid,pcpu,stime,args |sort -k 2 -r |head -n $TOP_PROCESSES)"
    echo "$TOP_PROCESS_CPU" | tee -a $REPORT
  fi
done
fi

if [ -e /tmp/health_disk_report ]
then
for i in `cat /tmp/health_disk_report`
do
  if [ $i -gt $DISK_WARN ]
  then
    MAIL_SENT=1
  fi
done
fi

if [ -e /tmp/health_ram_report ]
then
for i in `cat /tmp/health_ram_report`
do
  if [ $i -gt $RAM_WARN ]
  then
    MAIL_SENT=1
    TITLE="$( echo "Top 15 process are consuing more Memory")"
    echo $TITLE | tee -a $REPORT
    TOP_PROCESS_MEM="$(ps -eo pid,pmem,stime,args |sort -k 2 -r |head -n $TOP_PROCESSES)"
    echo "$TOP_PROCESS_MEM" | tee -a $REPORT
  fi

done
fi

if [[ $MAIL_SENT == 1 ]]
then
  echo "Please find the `hostname` System Health Report"|mail -s "`hostname` - System Health Report" \
  -a $REPORT $EMAIL
  echo "Email has been sent to $EMAIL"
fi
rm -rf /tmp/health*
rm -rf $REPORT

