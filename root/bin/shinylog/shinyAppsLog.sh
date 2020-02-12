#!/bin/bash
#
# Program
# 	紀錄 shiny apps 連線人數
# History
# 	2020-02-12 first release
# schedule
# 	/etc/cron.d/shinylogfile
# 	每 1 分鐘執行一次
#
####################################################################
# 0. 環境設定
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
export deployDir="/opt/shiny-server/samples/sample-apps/"

# 設定 log 存放目錄
basedir="/root/bin/shinylog"
[ ! -d "$basedir" ] && mkdir $basedir 

# log 檔名
basefile=$basedir/$(date +"%Y-%m-%d").csv
if [ ! -f "$basefile" ]; then
	touch $basefile
	echo "TIME,APP,PID,USER,PR,NI,VIRT,RES,SHR,S,%CPU,%MEM,TIME+,COMMAND,COUNTS" >> $basefile
fi

####################################################################
# 1.檢查所需指令是否存在與shiny服務是否啟動

# 檢查所需指令
tools="awk grep cut netstat top"
allExist="true"
for tool in $tools; do
	which $tool > /dev/null 2>&1
	if [ "$?" != "0" ]; then
		echo -e "command ${tool} not found."
		allExist="false"
	fi
done
if [ "$allExist" != "true" ]; then
	echo -e "stop program!"
	exit 1
fi

# 檢查 shiny-server 是否啟動
shinyIsRunning=$(systemctl is-active shiny-server.service)
if [ "$shinyIsRunning" != "active" ]; then
	echo -e "Shiny Server is not running. So stop program."
	exit 1
fi

####################################################################
# 2.輸出資訊

# 抓取 shiny server PID
shinyPID=$(top -b -n1 -u shiny | grep " R*$" | grep shiny | awk '{print $1}')
if [ -z "$shinyPID" ]; then
	echo -e "cannot find shiny server PID, stop program."
	exit 1
fi
PIDCount=$(echo $shinyPID | wc -w)

function outputLog(){
	users=$(netstat -p | grep "$1" | grep ESTABLISHED | wc -l)
	infos=$(top -b -n1 -p "$1" | tail -1)
	datetime=$(date +"%Y/%m/%d %H:%M:%S")
	# 抓出 app 名稱
	apps=$(lsof -p "$1" | grep "$deployDir" | awk '{print $9}' | awk '{FS="/"} {print $6}' | uniq)	
	
	output="$datetime $apps $infos $users"
	echo $output | sed 's/ /,/2g' >> $basefile 2>/dev/null
}

if [ "$PIDCount" -gt 1 ]; then
	for sPID in $shinyPID; do
		outputLog $sPID
	done
else
	outputLog $shinyPID
fi