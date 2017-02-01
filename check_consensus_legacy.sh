## Version 0.9.5.1
#!/bin/bash

## Check for config file
CONFIG_FILE="mrv_config.json"

##  Read config file
CONFIGFILE=$(cat "$CONFIG_FILE")
SECRET=$( echo "$CONFIGFILE" | jq -r '.secret')
SRV1=$( echo "$CONFIGFILE" | jq -r '.srv1')
PRT=$( echo "$CONFIGFILE" | jq -r '.port')
PRTS=$( echo "$CONFIGFILE" | jq -r '.https_port')
SERVERS=()
### Get servers array
size=$( echo "$CONFIGFILE" | jq '.servers | length') 
i=0

while [ $i -le "$size" ]    
do
	SERVERS[$i]=$(echo "$CONFIGFILE" | jq -r --argjson i $i '.servers[$i]')
	i=$((i + 1))
done
###
#########################

# Set colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESETCOLOR=$(tput sgr0)

## Log start of script
date +"%Y-%m-%d %H:%M:%S || ${GREEN}Starting MrV's legacy consensus script${RESETCOLOR}"

while true; do
	## Get recent log
 	INADEQUATE=$(tail ~/lisk-main/logs/lisk.log -n 2| grep 'Inadequate')
	date +"%Y-%m-%d %H:%M:%S || ${RED}WARNING: Inadequate consensus to forge.${RESETCOLOR}"
	
	if [ -n "$INADEQUATE" ];
	then
		## Disable forging on local server first.  If successful, loop through servers until we are able to enable forging on one
		DISABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 3 --retry-delay 0 --retry-max-time 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SRV1""$PRTS"/api/delegates/forging/disable | jq '.success')
		if [ "$DISABLEFORGE" = "true" ];
		then
			for SERVER in "${SERVERS[@]}"
			do
				ENABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/enable | jq '.success')
				if [ "$ENABLEFORGE" = "true" ];
				then
					date +"%Y-%m-%d %H:%M:%S || ${CYAN}Successsfully switching to Server $SERVER to try and forge.${RESETCOLOR}"
					sleep 10
					break ## Leave servers loop
				else
					date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to enable forging on $SERVER.  Trying next server.${RESETCOLOR}"
				fi
			done
		else
			date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to disable forging on $SRV1.${RESETCOLOR}"
		fi
	fi
	date +"%Y-%m-%d %H:%M:%S || ${GREEN}Everything is Okay.${RESETCOLOR}"
	sleep 1
done
