## init_height_and_rebuild.sh
## get newest check_height_and_rebuild.sh and run it
## Tested with jq 1.5.1 on Ubuntu 16.04.1
## DISCLAIMER: nodes sometimes rebuild from block 1 with this, not sure why yet
#!/bin/bash

SH_FILE="check_height_and_rebuild.sh"
LOG_FILE="heightRebuild.log"

##parse_option() {
##  OPTIND=2
##  while getopts :s opt; do
##     case $opt in
##       s) SRV=$OPTARG ;;
##     esac
##   done
##}

check_running() {
	# Check if it is running
	if pgrep -fl $SH_FILE > /dev/null
	then
		echo "Killing process"
		pkill -f $SH_FILE -9
	else
		echo "Not currently running"
	fi
}

usage() {
  echo "Usage: $0 <start|stop|upgrade>"
  echo "start         -- starts script"
  echo "stop          -- stops script"
  echo "upgrade       -- upgrades and runs script"
}

case $1 in 
"start" )
	##parse_option $@
	if [[ ! -e "$LOG_FILE" ]] ; then
		touch "$LOG_FILE"
	fi
	if [[ ! -e "$SH_FILE" ]] ; then
		wget "https://lisktools.io/backups/check_height_and_rebuild.sh"
	fi
	
	check_running
	echo "Starting Script"
	nohup bash $SH_FILE -S $SRV  > $LOG_FILE 2>&1&
;;
"stop" ) 
	check_running
;;
"upgrade" ) 
	##parse_option $@
	check_running
	
	if [[ -e "$SH_FILE" ]] ;
	then
		rm "$SH_FILE"
	fi
	
	wget "https://lisktools.io/backups/check_height_and_rebuild.sh"
	echo "Starting Script"
	nohup bash $SH_FILE -S $SRV  > $LOG_FILE 2>&1&
;;
*)
	echo "Error: Unrecognized command."
	echo ""
	echo "Available commands are: install upgrade"
	usage
	exit 1
exit 1
;;
esac
