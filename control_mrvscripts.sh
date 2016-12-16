## control_mrvscripts.sh
## Version 0.9.0
## Tested with jq 1.5.1 on Ubuntu 16.04.1
#!/bin/bash

SH_FILE="check_height_and_rebuild.sh"
LOG_FILE="heightRebuild.log"
CONSENSUS_SH_FILE="check_consensus.sh"
CONSENSUS_LOG_FILE="consensus.log"

start_height() {
	if [[ ! -e "$LOG_FILE" ]] ; then
		touch "$LOG_FILE"
	fi
	if [[ ! -e "$SH_FILE" ]] ; then
		wget "https://raw.githubusercontent.com/mrv777/LiskScripts/master/check_height_and_rebuild.sh"
	fi
	
	echo "Starting heightRebuild Script"
	nohup bash $SH_FILE -S $SRV  > $LOG_FILE 2>&1&  ## SRV???
}

check_height_running() {
	# Check if it is running
	if pgrep -fl $SH_FILE > /dev/null
	then
		echo "Killing heightRebuild process"
		pkill -f $SH_FILE -9
	else
		echo "heightRebuild is not currently running"
	fi
}

upgrade_height() {
	if [[ -e "$SH_FILE" ]] ;
	then
		rm "$SH_FILE"
	fi
	
	wget "https://raw.githubusercontent.com/mrv777/LiskScripts/master/check_height_and_rebuild.sh"
	echo "Starting heightRebuild Script"
	nohup bash $SH_FILE -S $SRV  > $LOG_FILE 2>&1&
}

start_consensus() {
	if [[ ! -e "$CONSENSUS_LOG_FILE" ]] ; then
		touch "$CONSENSUS_LOG_FILE"
	fi
	if [[ ! -e "$CONSENSUS_SH_FILE" ]] ; then
		wget "https://raw.githubusercontent.com/mrv777/LiskScripts/master/check_consensus.sh"
	fi
	
	echo "Starting consensus Script"
	nohup bash $CONSENSUS_SH_FILE -S $SRV  > $CONSENSUS_LOG_FILE 2>&1&
}

check_consensus_running() {
	# Check if it is running
	if pgrep -fl $CONSENSUS_SH_FILE > /dev/null
	then
		echo "Killing consensus process"
		pkill -f $CONSENSUS_SH_FILE -9
	else
		echo "Consensus is not currently running"
	fi
}

upgrade_consensus() {
	if [[ -e "$CONSENSUS_SH_FILE" ]] ;
	then
		rm "$CONSENSUS_SH_FILE"
	fi
	
	wget "https://raw.githubusercontent.com/mrv777/LiskScripts/master/check_consensus.sh"
	echo "Starting consensus Script"
	nohup bash $CONSENSUS_SH_FILE -S $SRV  > $CONSENSUS_SH_FILE 2>&1&
}

usage() {
  echo "Usage: $0 <start|stop|upgrade>"
  echo "start					-- starts both scripts"
  echo "start_consensus         -- starts consensus script"
  echo "start_rebuild         	-- starts height_rebuild script"
  echo "stop          			-- stops both scripts"
  echo "stop_consensus          -- stops consensus script"
  echo "stop_height          	-- stops height_rebuild script"
  echo "upgrade       			-- upgrades and runs both scripts"
}

case $1 in 
"start" )
	check_height_running
	start_height
	check_consensus_running
	start_consensus
;;
"start_consensus" )
	check_consensus_running
	start_consensus
;;
"start_rebuild" )
	check_height_running
	start_height
;;
"stop" ) 
	check_height_running
	check_consensus_running
;;
"stop_consensus" ) 
	check_consensus_running
;;
"stop_height" ) 
	check_height_running
;;
"upgrade" ) 
	check_height_running
	check_consensus_running
	
	upgrade_height
	upgrade_consensus
;;
*)
	echo "Error: Unrecognized command."
	echo ""
	echo "Available commands are: "
	usage
	exit 1
exit 1
;;
esac
