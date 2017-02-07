## Version 0.9.5.1
#!/bin/bash

## Check for config file
CONFIG_FILE="mrv_config.json"

##  Read config file
CONFIGFILE=$(cat "$CONFIG_FILE")
SECRET=$( echo "$CONFIGFILE" | jq -r '.secret')
PRT=$( echo "$CONFIGFILE" | jq -r '.port')
PRTS=$( echo "$CONFIGFILE" | jq -r '.https_port')
PBK=$( echo "$CONFIGFILE" | jq -r '.pbk')
SERVERS=()
### Get servers array
SIZE=$( echo "$CONFIGFILE" | jq '.manage_servers | length') 
i=0

while [ $i -le $((SIZE-1)) ]    
do
	SERVERS[$i]=$(echo "$CONFIGFILE" | jq -r --argjson i $i '.manage_servers[$i]')
    i=$(( i + 1 ))
done
###
#########################

## Set colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESETCOLOR=$(tput sgr0)

FORGING=0
PREVIOUSFORGING=0

## Log start of script
date +"%Y-%m-%d %H:%M:%S || ${GREEN}Starting MrV's management script${RESETCOLOR}"

while true; do
	SERVERSINFO=()
	SERVERSFORGING=()
	SERVERSCONSENSUS=()
	NUM=0
	HIGHHEIGHT=0
	
	## Get info on all servers
	for SERVER in "${SERVERS[@]}"
	do
		## Get next server's height and consensus
		SERVERINFO=$(curl --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -s -S "http://"$SERVER""$PRT"/api/loader/status/sync")
		if [[ -z "$SERVERINFO" ]]; ## If null, try one more time to get server status
		then
			SERVERINFO=$(curl --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -s -S "http://"$SERVER""$PRT"/api/loader/status/sync")
		fi
		HEIGHT=$( echo "$SERVERINFO" | jq '.height')
		CONSENSUS=$( echo "$SERVERINFO" | jq '.consensus')
		
		## Check if server is off
		if ! [[ "$HEIGHT" =~ ^[0-9]+$ ]];
		then
			date +"%Y-%m-%d %H:%M:%S || ${RED}$SERVER is off?${RESETCOLOR}"
			HEIGHT="0"
			FORGE="false"
			CONSENSUS="0"
		else
			## Get forging status of server
			FORGE=$(curl --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -s "http://"$SERVER""$PRT"/api/delegates/forging/status?publicKey="$PBK| jq '.enabled')
			if [[ -z "$FORGE" ]]; ## If null, try one more time to get forging status
			then
				FORGE=$(curl --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -s "http://"$SERVER""$PRT"/api/delegates/forging/status?publicKey="$PBK| jq '.enabled')
			fi
			if [[ "$FORGE" == "true" ]]; ## Current server forging
			then
				FORGING=$NUM
			fi
		fi
		
		## Find highest height
		if [ "$HEIGHT" -gt "$HIGHHEIGHT" ];
		then
			HIGHHEIGHT=$HEIGHT
		fi
		
		SERVERSINFO[$NUM]=$HEIGHT
		SERVERSFORGING[$NUM]=$FORGE
		SERVERSCONSENSUS[$NUM]=$CONSENSUS
		date +"%Y-%m-%d %H:%M:%S || $SERVER - Height:$HEIGHT - Consensus:$CONSENSUS - Forging:$FORGE"
		
		((NUM++))
	done
	
	NUM=0
	## Check if any servers are forging
	if ! [[ ${SERVERSFORGING[*]} =~ "true" ]];
	then
		for SERVER in "${SERVERS[@]}"
		do
			DIFF=$(( HIGHHEIGHT - ${SERVERSINFO[$NUM]} ))
			if [ "$DIFF" -lt "4" ] && [ "${SERVERSCONSENSUS[$NUM]}" -gt "50" ]; 
			then
				date +"%Y-%m-%d %H:%M:%S || ${YELLOW}No node forging.  Starting on $SERVER${RESETCOLOR}"
				ENABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/enable | jq '.success')
				if [ "$ENABLEFORGE" = "true" ];
				then
					date +"%Y-%m-%d %H:%M:%S || ${CYAN}Switching to Server $SERVER to try and forge.${RESETCOLOR}"
					PREVIOUSFORGING=$NUM
					break ## Leave servers loop
				else
					date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to enable forging on $SERVER.  Trying next server.${RESETCOLOR}"
				fi
			fi
			((NUM++))
		done
		continue  ## Start back at top of loop, now that one server is forging
	fi
	
	## Check that only one server is forging
	FORGINGCOUNT=0
	for FSTATUS in ${SERVERSFORGING[*]}; do
		if [[ $FSTATUS =~ true ]]; then
			(( FORGINGCOUNT++ ))
		fi
	done 
	if [ "$FORGINGCOUNT" -gt "1" ]
		then
			date +"%Y-%m-%d %H:%M:%S || ${RED}Multiple servers forging!${RESETCOLOR}"
			for SERVER in "${SERVERS[@]}"
			do
				## Disable forging on all servers first
				curl -s -S --connect-timeout 1 --retry 3 --retry-delay 0 --retry-max-time 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/disable
			done
			sleep 1 ## Make sure disable had time to take effect
			for index in "${!SERVERS[@]}"
			do
				DIFF=$(( HIGHHEIGHT - ${SERVERSINFO[$index]} ))
				if [ "$DIFF" -lt "4" ] && [ "${SERVERSCONSENSUS[$NUM]}" -gt "50" ]; 
				then
					ENABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"${SERVERS[$index]}""$PRTS"/api/delegates/forging/enable | jq '.success')
					if [ "$ENABLEFORGE" = "true" ];
					then
						PREVIOUSFORGING=$index
						date +"%Y-%m-%d %H:%M:%S || ${CYAN}Setting forging to ${SERVERS[$index]}${RESETCOLOR}"
						break ## Exit loop once we find the first server at an acceptable height and consensus
					else
						date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to enable forging on ${SERVERS[$index]}.  Trying next server.${RESETCOLOR}"
					fi
				fi
			done
		fi

	if [[ $PREVIOUSFORGING != "$FORGING" ]];
	then
		date +"%Y-%m-%d %H:%M:%S || ${YELLOW}Different server forging! Previous=${SERVERS[$PREVIOUSFORGING]},Current=${SERVERS[$FORGING]}. Waiting 15 seconds${RESETCOLOR}"
		sleep 9
	else  ## Same server still forging, check that everything still looks good on it
		date +"%Y-%m-%d %H:%M:%S || Highest Height: $HEIGHT"
		
		##Check that it is the main server forging
		if [ "$FORGING" != "0" ];
		then
			date +"%Y-%m-%d %H:%M:%S || ${YELLOW}Main server not forging${RESETCOLOR}"
			DIFF=$(( HIGHHEIGHT - ${SERVERSINFO[0]} ))
			if [ "$DIFF" -lt "4" ] && [ "${SERVERSCONSENSUS[0]}" -gt "50" ]; 
			then
				DISABLEFORGE=$(curl -s -S --connect-timeout 2 --retry 3 --retry-delay 0 --retry-max-time 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"${SERVERS[$FORGING]}""$PRTS"/api/delegates/forging/disable | jq '.success')
				if [ "$DISABLEFORGE" = "true" ];
				then
					sleep 1 ## Make sure disable had time to take effect
					ENABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"${SERVERS[0]}""$PRTS"/api/delegates/forging/enable | jq '.success')
					if [ "$ENABLEFORGE" = "true" ];
					then
						PREVIOUSFORGING=0
						date +"%Y-%m-%d %H:%M:%S || ${CYAN}Setting forging to back to main server: ${SERVERS[0]}${RESETCOLOR}"
						continue ## Exit loop once if we can set forging back to main server
					else
						date +"%Y-%m-%d %H:%M:%S || ${RED}Failed setting forging to back to main server: ${SERVERS[0]}. Trying second server: ${SERVERS[1]}${RESETCOLOR}"
						curl -s -S --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"${SERVERS[1]}""$PRTS"/api/delegates/forging/enable
						PREVIOUSFORGING=1
						sleep 30 ## TEMPORARY CODE, don't want to keep trying main server if there is an issue
						continue ## Exit loop
					fi
				else
					date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to disable forging on server: ${SERVERS[$FORGING]}${RESETCOLOR}"
				fi
			fi
		fi
	
		DIFF=$(( HIGHHEIGHT - ${SERVERSINFO[$FORGING]} ))
		if [ "$DIFF" -gt "3" ]
		then
			date +"%Y-%m-%d %H:%M:%S || ${RED}${SERVERS[$FORGING]} too low of height.${RESETCOLOR}"
			for SERVER in "${SERVERS[@]}"
			do
				## Disable forging on all servers first
				curl -s -S --connect-timeout 2 --retry 3 --retry-delay 0 --retry-max-time 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/disable
			done
			sleep 1 ## Make sure disable had time to take effect
			for index in "${!SERVERS[@]}"
			do
				DIFF=$(( HIGHHEIGHT - ${SERVERSINFO[$index]} ))
				if [ "$DIFF" -lt "4" ] && [ "${SERVERSCONSENSUS[$NUM]}" -gt "50" ]; 
				then
					ENABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"${SERVERS[$index]}""$PRTS"/api/delegates/forging/enable | jq '.success')
					if [ "$ENABLEFORGE" = "true" ];
					then
						FORGING=$index
						date +"%Y-%m-%d %H:%M:%S || ${CYAN}Switching to ${SERVERS[$index]}${RESETCOLOR}"
						break ## Exit loop once we find the first server at an acceptable height and consensus
					else
						date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to enable forging on ${SERVERS[$index]}.  Trying next server.${RESETCOLOR}"
					fi
				fi
			done
		fi
	fi
	
	
	## Record which server was forging before sleep
	PREVIOUSFORGING=$FORGING
	## Sleep for 6 seconds
  sleep 6
done
