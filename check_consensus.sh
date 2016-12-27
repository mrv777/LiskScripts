## Version 0.9.4
#!/bin/bash

## Check for config file
CONFIG_FILE="mrv_config.json"

##  Read config file
CONFIGFILE=$(cat "$CONFIG_FILE")
SECRET=$( echo "$CONFIGFILE" | jq -r '.secret')
LDIRECTORY=$( echo "$CONFIGFILE" | jq -r '.lisk_directory')
SRV1=$( echo "$CONFIGFILE" | jq -r '.srv1')
PRT=$( echo "$CONFIGFILE" | jq -r '.port')
PRTS=$( echo "$CONFIGFILE" | jq -r '.https_port')
pbk=$( echo "$CONFIGFILE" | jq -r '.pbk')
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

#Set text delay and forging log delays
TXTDELAY=1
FORGEDDELAY=0

# Set colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESETCOLOR=$(tput sgr0)

## Log start of script
date +"%Y-%m-%d %H:%M:%S || ${GREEN}Starting MrV's consensus script${RESETCOLOR}"


# Set Lisk directory
function ChangeDirectory(){
	cd ~
	eval "cd $LDIRECTORY"
}

#---------------------------------------------------------------------------
# Looping while node is syncing blockchain 
# from Nerigal
function SyncState()
{
	result='true'
	while [[ -z $result || $result != 'false' ]]
	do
		date +"%Y-%m-%d %H:%M:%S || Blockchain syncing"
		result=$(curl --connect-timeout 3 -s "http://$SRV1$PRT/api/loader/status/sync" | jq '.syncing')
		sleep 2
	done

	date +"%Y-%m-%d %H:%M:%S || Looks like blockchain is finished syncing."
}
#---------------------------------------------------------------------------


while true;
do
	## Get forging status of server
	FORGE=$(curl --connect-timeout 1 --retry 3 --retry-delay 0 --retry-max-time 3 -s "http://"$SRV1""$PRT"/api/delegates/forging/status?publicKey="$pbk| jq '.enabled')
	if [[ "$FORGE" == "true" ]]; ## Only check log and try to switch forging if needed, if server is currently forging
	then
		## Get current server's height and consensus
		SERVERLOCAL=$(curl --connect-timeout 1 --retry 3 --retry-delay 0 --retry-max-time 3 -s "http://"$SRV1""$PRT"/api/loader/status/sync")
		HEIGHTLOCAL=$( echo "$SERVERLOCAL" | jq '.height')
		CONSENSUSLOCAL=$( echo "$SERVERLOCAL" | jq '.consensus')
		## Get recent log
		LOG=$(tail ~/lisk-main/logs/lisk.log -n 10)
		
		## Only look for forged block in log if we didn't just log it
		if [[ "$FORGEDDELAY" -eq "0" ]];
		then
			## Log when a block is forged
			FORGEDBLOCKLOG=$( echo "$LOG" | grep 'Forged new block')

			if [[ -n "$FORGEDBLOCKLOG" ]];
			then
				date +"%Y-%m-%d %H:%M:%S || ${GREEN}$FORGEDBLOCKLOG${RESETCOLOR}"
				FORGEDDELAY=40
			fi
		elif [[ "$FORGEDDELAY" -gt "0" ]]
		then
			((FORGEDDELAY--))
		fi

		## Check log if node is recovering close to forging time
		LASTLINE=$( echo "$LOG" | grep 'starting recovery')
		if [[ -n "$LASTLINE" ]];
		then
			delegates=$(curl --connect-timeout 3 -s "http://"$SRV1""$PRT"/api/delegates/getNextForgers" | jq '.delegates')
			date +"%Y-%m-%d %H:%M:%S || ${YELLOW}Node is recovering.  Looking for delegate forging soon matching $pbk${RESETCOLOR}"
			if [[ $delegates == *"$pbk"* ]];
			then
			date +"%Y-%m-%d %H:%M:%S || ${RED}You are forging soon, but your node is recovering. Looking to switch server while recovering.${RESETCOLOR}"
				for SERVER in "${SERVERS[@]}"
				do
					## Get next server's height and consensus
					SERVERINFO=$(curl --connect-timeout 3 -s -S "http://"$SERVER""$PRT"/api/loader/status/sync")
					HEIGHT=$( echo "$SERVERINFO" | jq '.height')
					CONSENSUS=$( echo "$SERVERINFO" | jq '.consensus')

					## Make sure next server is not more than 3 blocks behind this server and consensus is better, then switch
					if [[  -n "$HEIGHT" ]];
					then
						diff=$(( $HEIGHTLOCAL - $HEIGHT ))
					else
						diff="999"
					fi
					## if [ "$diff" -lt "3" ] && [ "$CONSENSUS" -gt "$CONSENSUSLOCAL" ]; ## Removed for now as I believe consensus read from API isn't updated every second to be fully accurate
					if [ "$diff" -lt "3" ]; 
					then
						DISABLEFORGE=$(curl -s -S --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SRV1""$PRTS"/api/delegates/forging/disable | jq '.success')
						if [ "$DISABLEFORGE" = "true" ];
						then
							curl -s -S --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/enable
							date +"%Y-%m-%d %H:%M:%S || ${CYAN}Switching to Server $SERVER with a consensus of $CONSENSUS as your node is recovering.${RESETCOLOR}"
							break
						else
							date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to disable forging on $SRV1 that is recovering before forging${RESETCOLOR}"
						fi
					fi
				done
			fi
		fi

		## Check log for Inadequate consensus or Fork & Forged while forging
		INADEQUATE=$( echo "$LOG" | grep 'Inadequate')
		FORK=$( echo "$LOG" | grep 'Fork')
		FORGEDBLOCKLOG=$( echo "$LOG" | grep 'Forged new block')
		if [ -n "$INADEQUATE" ] || ([ -n "$FORK" ] && [ -n "$FORGEDBLOCKLOG" ]);
		then
			if [ -n "$FORK" ];
			then
				date +"%Y-%m-%d %H:%M:%S || ${RED}WARNING: Fork and Forged in log.${RESETCOLOR}"
			else
				date +"%Y-%m-%d %H:%M:%S || ${RED}WARNING: Inadequate consensus to forge.${RESETCOLOR}"
			fi
			
			## Disable forging on local server first.  If successful, loop through servers until we are able to enable forging on one
			DISABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 3 --retry-delay 0 --retry-max-time 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SRV1""$PRTS"/api/delegates/forging/disable | jq '.success')
			if [ "$DISABLEFORGE" = "true" ];
			then
				for SERVER in "${SERVERS[@]}"
				do
					ENABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/enable | jq '.success')
					if [ "$ENABLEFORGE" = "true" ];
					then
						date +"%Y-%m-%d %H:%M:%S || ${CYAN}Switching to Server $SERVER to try and forge.${RESETCOLOR}"
						break ## Leave servers loop
					else
						date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to enable forging on $SERVER.  Trying next server.${RESETCOLOR}"
					fi
				done
			else
				date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to disable forging on $SRV1.${RESETCOLOR}"
			fi
		fi
		(( ++TXTDELAY ))
		if [[ "$TXTDELAY" -gt "60" ]];  ## Wait 30 seconds to update running status to not overcrowd log
		then
			date +"%Y-%m-%d %H:%M:%S || ${GREEN}Still working at block $HEIGHTLOCAL with a consensus of $CONSENSUSLOCAL${RESETCOLOR}"
			TXTDELAY=1
		fi
		sleep 0.5
	else
		(( ++TXTDELAY ))
		if [[ "$TXTDELAY" -gt "30" ]];  ## Wait 30 seconds to update running status to not overcrowd log
		then
			date +"%Y-%m-%d %H:%M:%S || This server is not forging"
			TXTDELAY=1
		fi
		sleep 1
	fi
done
