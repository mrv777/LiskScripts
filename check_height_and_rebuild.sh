## check_height_and_rebuild.sh
## Version 0.9.6
## Tested with jq 1.5.1 on Ubuntu 16.04.1
## 
#!/bin/bash

## Check for config file
CONFIG_FILE="mrv_config.json"

##  Read config file
CONFIGFILE=$(cat "$CONFIG_FILE")
##SECRET=$( echo "$CONFIGFILE" | jq -r '.secret') ## Uncomment this line if you want this script to re-enable forging when done.  Should only do this if you only have one node and no other scripts running
LDIRECTORY=$( echo "$CONFIGFILE" | jq -r '.lisk_directory')
SRV=127.0.0.1:8000

# Set colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
cyan=`tput setaf 6`
resetColor=`tput sgr0`

## Log start of script
date +"%Y-%m-%d %H:%M:%S || ${green}Starting MrV's height checking script${resetColor}"

## Make sure we are in the correct directory (corsaro suggestion)
function ChangeDirectory(){
	cd ~
	eval "cd $LDIRECTORY"
}

# gregorst
if [[ "$EUID" -eq 0 ]];
then
  echo "Error: Do not run this as root. Exiting."
  exit 1
fi

#---------------------------------------------------------------------------
# Looping while node is building blockchain 
# from Nerigal
function SyncState()
{
	TIMER=0 ##Timer to make sure this loop hasn't been running for too long
	result='true'
	while [[ -z $result || $result != 'false' ]]
	do
		date +"%Y-%m-%d %H:%M:%S || Blockchain syncing"
		result=`curl -s "http://$SRV/api/loader/status/sync"| jq '.syncing'`
		sleep 2
		## Check that lisk is running still and didn't crash when trying to resync
		STATUS="$(bash lisk.sh status | grep 'Lisk is running as PID')"
		if [[ -z "$STATUS" ]];
		then
			sleep 60 ## Wait 60 seconds to make sure Lisk isn't just down for a rebuild
			STATUS="$(bash lisk.sh status | grep 'Lisk is running as PID')"
			if [[ -z "$STATUS" ]];
			then
				date +"%Y-%m-%d %H:%M:%S || ${red}WARNING: Lisk does not seem to be running.  Trying a stop and start.${resetColor}"
				bash lisk.sh stop
				sleep 5
				bash lisk.sh start
				sleep 2
			fi
		fi
		
		## Check if loop has been running for too long
		(( ++TIMER ))
		if [ "$TIMER" -gt "600" ]; 
		then
			date +"%Y-%m-%d %H:%M:%S || ${yellow}WARNING: Blockchain has been trying to sync for 20 minutes.  We will try a rebuild.${resetColor}"
			ChangeDirectory
			find_newest_snap_rebuild
			sleep 45
			TIMER=0  ##Reset Timer
		fi
	done
	
	date +"%Y-%m-%d %H:%M:%S || ${green}Looks like rebuilding finished.${resetColor}"
	if [[ -n "$SECRET" ]];
	then
		curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' http://"$SRV"/api/delegates/forging/enable ## If you want this script to reenable forging when done
	fi
}
#---------------------------------------------------------------------------


## Thanks to cc001 and hagie for improvements here and cc001 for comparing blocks instead of size and timestamp
find_newest_snap_rebuild(){

	SNAPSHOTS=(
	  https://downloads.lisk.io/lisk/main			## Official
	  https://snapshot.liskwallet.net			## isabella
	  https://snapshot.lisknode.io				## Gr33nDrag0n
	  https://lisktools.io/backups				## MrV
	)
	
	MATCHER="lisk_main_backup-[0-9]*\.gz"

	BESTSNAP=""
	BESTSNAPBLOCK=0
	
	BESTSNAP2=""
	BESTSNAPBLOCK2=0
	
	for SNAPSHOT in ${SNAPSHOTS[@]}
	do
	  BACKUP=`curl -s -L $SNAPSHOT | grep -o "$MATCHER" | sort | tail -n 1`
	  BLOCK=`echo $BACKUP | grep -oh "[0-9]*"`
	  date +"%Y-%m-%d %H:%M:%S || $SNAPSHOT | Block height: $BLOCK"
	  if [ -z "$BLOCK" ];
	  then
	  	date +"%Y-%m-%d %H:%M:%S || ${yellow}WARNING: Couldn't locate block number${resetColor}"
	  else
		  if [ "$BLOCK" -gt "$BESTSNAPBLOCK" ];
		  then
			BESTSNAPBLOCK2=$BESTSNAPBLOCK
			BESTSNAP2=$BESTSNAP
		
			BESTSNAPBLOCK=$BLOCK
			BESTSNAP=$SNAPSHOT
		  elif [ "$BLOCK" -gt "$BESTSNAPBLOCK2" ]; ## Check if the second is newer
		  then	 
		  	 BESTSNAPBLOCK2=$BLOCK
			 BESTSNAP2=$SNAPSHOT
		  fi
	  fi
	done
	
	## Randomly choose between the best 2 snapshots to prevent everyone downloading from the same source
	WHICHSNAP=$((1 + RANDOM % 2))
    	
	ChangeDirectory ## Make sure we are in the correct directory
	if [ "$WHICHSNAP" -eq "1" ];
	then
		date +"%Y-%m-%d %H:%M:%S || Newest snap: $BESTSNAP at block: $BESTSNAPBLOCK"
    		bash lisk.sh rebuild -u $BESTSNAP
	else
		date +"%Y-%m-%d %H:%M:%S || Newest snap: $BESTSNAP2 at block: $BESTSNAPBLOCK2"
    		bash lisk.sh rebuild -u $BESTSNAP2
	fi
}

top_height(){
	## Get height of your 100 peers and save the highest value
	## Thanks to wannabe_RoteBaron for this improvement
	HEIGHT=$(curl -s http://$SRV/api/peers | jq '.peers[].height' | sort -nu | tail -n1)
	## Make sure height is not empty, if it is empty try the call until it is not empty
	while [ -z "$HEIGHT" ]
	do
		sleep 1
    		HEIGHT=$(curl -s http://$SRV/api/peers | jq '.peers[].height' | sort -nu | tail -n1)
    	done
}

## Get height of this server and see if it's greater or within 4 of the highest
local_height() {
	## Make sure local height is not empty, if it is empty try the call until it is not empty
	CHECKSRV=`curl -s "http://$SRV/api/loader/status/sync"| jq '.height'`
	while [ -z "$CHECKSRV" ]
	do
    	sleep 1
		CHECKSRV=`curl -s "http://$SRV/api/loader/status/sync"| jq '.height'`
	done
	diff=$(( $HEIGHT - $CHECKSRV ))
	if [ "$diff" -gt "5" ]
	then
		## Thank you doweig for better output formating
        	date +"%Y-%m-%d %H:%M:%S || ${yellow}Reloading! Local: $CHECKSRV, Highest: $HEIGHT, Diff: $diff${resetColor}"
		ChangeDirectory ## Make sure we are in the correct directory
		bash lisk.sh reload  # 0.5.1 often solves short stucks by itself, but reload anyways :)
		sleep 20
		SyncState
		##date +"%Y-%m-%d %H:%M:%S || Sleeping for 140 seconds to wait for autocorrect! Local: $CHECKSRV, Highest: $HEIGHT, Diff: $diff"
		##sleep 140  #normally a short stuck is solved by itself in less then 140 seconds | by corsaro || Costs too much time though
		
		## Make sure local height is not empty, if it is empty try the call until it is not empty
		CHECKSRV=`curl -s "http://$SRV/api/loader/status/sync"| jq '.height'`
		while [ -z "$CHECKSRV" ]
		do
    		sleep 1
			CHECKSRV=`curl -s "http://$SRV/api/loader/status/sync"| jq '.height'`
		done
		
		## Rebuild if still out of sync after reload
		diff=$(( $HEIGHT - $CHECKSRV ))
		if [ "$diff" -gt "7" ]
		then
			## Thank you doweig for better output formating
			date +"%Y-%m-%d %H:%M:%S || ${red}Rebuilding! Local: $CHECKSRV, Highest: $HEIGHT, Diff: $diff${resetColor}"
			find_newest_snap_rebuild
			sleep 90
			SyncState
			#sleep 420
			## Thank you corsaro for this improvement
			## while true; do
			## 	s1=`curl -k -s "http://$SRV/api/loader/status/sync"| jq '.height'`
			## 	sleep 30
			## 	s2=`curl -k -s "http://$SRV/api/loader/status/sync"| jq '.height'`

			## 	diff=$(( $s2 - $s1 ))
			## 	if [ "$diff" -gt "5" ];
			## 	then
			## 		echo "$s2" "is a lot greater then " "$s1"
			## 		echo "It looks like rebuild has not finished yet. Waiting longer to continue"
			## 	else
			## 		echo "" "$s1" " " "$s2"
			## 		echo "Looks like rebuilding finished. We can stop this"
			## 		if [[ -z "$SECRET" ]];
			## 		then
			## 			curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' http://"$SRV"/api/delegates/forging/enable ## If you want this script to reenable forging when done
			## 		fi
			## 		break
			## 	fi
			## done
		else
			if [[ -n "$SECRET" ]];
			then
				curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' http://"$SRV"/api/delegates/forging/enable ## Uncomment this line if you want this script to reenable forging when done
			fi
		fi
	fi
}
ChangeDirectory  ## Enter lisk directory
while true; do
	## Check that lisk is running first!!
	STATUS="$(bash lisk.sh status | grep 'Lisk is running as PID')"
	if [[ -z "$STATUS" ]];
	then
		sleep 90 ## Wait 90 seconds to make sure Lisk isn't just down for a rebuild
		STATUS="$(bash lisk.sh status | grep 'Lisk is running as PID')"
		if [[ -z "$STATUS" ]];
		then
			date +"%Y-%m-%d %H:%M:%S || ${red}WARNING: Lisk does not seem to be running.  Trying a stop and start.${resetColor}"
			bash lisk.sh stop
			sleep 5
			bash lisk.sh start
			sleep 2
		fi
	fi
	
	top_height
	local_height

	## Thank you doweig for better output formating
	date +"%Y-%m-%d %H:%M:%S || ${green}Local: $CHECKSRV, Highest: $HEIGHT, Diff: $diff${resetColor}"
	sleep 10
done
