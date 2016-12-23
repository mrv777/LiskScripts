## Version 0.9.3
#!/bin/bash

## Check for config file
CONFIG_FILE="mrv_config.json"

##  Read config file
CONFIGFILE=$(cat "$CONFIG_FILE")
SECRET=$( echo "$CONFIGFILE" | jq -r '.secret')
PRT=$( echo "$CONFIGFILE" | jq -r '.port')
PRTS=$( echo "$CONFIGFILE" | jq -r '.https_port')
pbk=$( echo "$CONFIGFILE" | jq -r '.pbk')
SERVERS=()
### Get servers array
size=$( echo "$CONFIGFILE" | jq '.manage_servers | length') 
i=0

while [ $i -le $((size-1)) ]    
do
	SERVERS[$i]=$(echo "$CONFIGFILE" | jq -r --argjson i $i '.manage_servers[$i]')
    i=`expr $i + 1`
done
###
#########################

## Set colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
cyan=`tput setaf 6`
resetColor=`tput sgr0`

## Start counter for server 1 reset at 0
DELAYCOUNT=0
FORGING=0
PREVIOUSFORGING=0

## Log start of script
date +"%Y-%m-%d %H:%M:%S || ${green}Starting MrV's management script${resetColor}"

while true; do
	SERVERSINFO=()
	SERVERSFORGING=()
	SERVERSCONSENSUS=()
	num=0
	HIGHHEIGHT=0
	
	## Get info on all servers
	for SERVER in ${SERVERS[@]}
	do
		## Get next server's height and consensus
		SERVERINFO=$(curl --connect-timeout 2 -s -S "http://"$SERVER""$PRT"/api/loader/status/sync")
		if [[ -z "$SERVERINFO" ]]; ## If null, try one more time to get server status
		then
			SERVERINFO=$(curl --connect-timeout 2 -s -S "http://"$SERVER""$PRT"/api/loader/status/sync")
		fi
		HEIGHT=$( echo "$SERVERINFO" | jq '.height')
		CONSENSUS=$( echo "$SERVERINFO" | jq '.consensus')
		
		## Check if server is off
		if ! [[ "$HEIGHT" =~ ^[0-9]+$ ]];
		then
			date +"%Y-%m-%d %H:%M:%S || ${red}$SERVER is off?${resetColor}"
			HEIGHT="0"
			FORGE="false"
			CONSENSUS="0"
		else
			## Get forging status of server
			FORGE=$(curl --connect-timeout 2 -s "http://"$SERVER""$PRT"/api/delegates/forging/status?publicKey="$pbk| jq '.enabled')
			if [[ -z "$FORGE" ]]; ## If null, try one more time to get forging status
			then
				FORGE=$(curl --connect-timeout 2 -s "http://"$SERVER""$PRT"/api/delegates/forging/status?publicKey="$pbk| jq '.enabled')
			fi
			if [[ "$FORGE" == "true" ]]; ## Current server forging
			then
				FORGING=$num
			fi
		fi
		
		## Find highest height
		if [ "$HEIGHT" -gt "$HIGHHEIGHT" ];
		then
			HIGHHEIGHT=$HEIGHT
		fi
		
		SERVERSINFO[$num]=$HEIGHT
		SERVERSFORGING[$num]=$FORGE
		SERVERSCONSENSUS[$num]=$CONSENSUS
		date +"%Y-%m-%d %H:%M:%S || $SERVER - Height:$HEIGHT - Consensus:$CONSENSUS - Forging:$FORGE"
		
		((num++))
	done
	
	num=0
	## Check if any servers are forging
	if ! [[ ${SERVERSFORGING[*]} =~ "true" ]];
	then
		for SERVER in ${SERVERS[@]}
		do
			diff=$(( $HIGHHEIGHT - ${SERVERSINFO[$num]} ))
			if [ "$diff" -lt "4" ] && [ "${SERVERSCONSENSUS[$num]}" -gt "50" ]; 
			then
				date +"%Y-%m-%d %H:%M:%S || ${yellow}No node forging.  Starting on $SERVER{resetColor}"
				curl -s -S --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/enable
				FORGING=$num
				break ## Exit loop once we find the first server at an acceptable height and consensus
			fi
			((num++))
		done
		continue  ## Start back at top of loop, now that one server is forging
	fi
	
	## Check that only one server is forging
	FORGINGCOUNT=0
	for fstatus in ${SERVERSFORGING[*]}; do
		if [[ $fstatus =~ true ]]; then
			(( FORGINGCOUNT++ ))
		fi
	done 
	if [ "$FORGINGCOUNT" -gt "1" ]
		then
			date +"%Y-%m-%d %H:%M:%S || ${red}Multiple servers forging!{resetColor}"
			for SERVER in ${SERVERS[@]}
			do
				## Disable forging on all servers first
				curl -s -S --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/disable
			done
			for index in "${!SERVERS[@]}"
			do
				diff=$(( $HIGHHEIGHT - ${SERVERSINFO[$index]} ))
				if [ "$diff" -lt "4" ] && [ "${SERVERSCONSENSUS[$num]}" -gt "50" ]; 
				then
					curl -s -S --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"${SERVERS[$index]}""$PRTS"/api/delegates/forging/enable
					FORGING=$index
					date +"%Y-%m-%d %H:%M:%S || ${cyan}Setting forging to ${SERVERS[$index]}{resetColor}"
					break ## Exit loop once we find the first server at an acceptable height and consensus
				fi
			done
		fi

	if [[ $PREVIOUSFORGING != $FORGING ]];
	then
		date +"%Y-%m-%d %H:%M:%S || ${yellow}Different server forging! Previous=${SERVERS[$PREVIOUSFORGING]},Current=${SERVERS[$FORGING]}. Waiting 30 seconds{resetColor}"
		sleep 24
	else  ## Same server still forging, check that everything still looks good on it
		date +"%Y-%m-%d %H:%M:%S || Highest Height: $HEIGHT"
	
		diff=$(( $HIGHHEIGHT - ${SERVERSINFO[$FORGING]} ))
		if [ "$diff" -gt "3" ]
		then
			date +"%Y-%m-%d %H:%M:%S || ${red}${SERVERS[$FORGING]} too low of height.{resetColor}"
			for SERVER in ${SERVERS[@]}
			do
				## Disable forging on all servers first
				curl -s -S --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/disable
			done
			for index in "${!SERVERS[@]}"
			do
				diff=$(( $HIGHHEIGHT - ${SERVERSINFO[$index]} ))
				if [ "$diff" -lt "4" ] && [ "${SERVERSCONSENSUS[$num]}" -gt "50" ]; 
				then
					curl -s -S --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"${SERVERS[$index]}""$PRTS"/api/delegates/forging/enable
					FORGING=$index
					date +"%Y-%m-%d %H:%M:%S || ${cyan}Switching to ${SERVERS[$index]}{resetColor}"
					break ## Exit loop once we find the first server at an acceptable height and consensus
				fi
			done
		fi
	fi
	
	
	## Record which server was forging before sleep
	PREVIOUSFORGING=$FORGING
	## Sleep for 6 seconds
  sleep 6
done
