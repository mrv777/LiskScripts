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

while [ $i -le $size ]    
do
	SERVERS[$i]=$(echo "$CONFIGFILE" | jq -r --argjson i $i '.servers[$i]')
    i=`expr $i + 1`
done
###
#########################

#Set text delay at 0
TXTDELAY=0
FORGEDDELAY=0

# Set colors
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
CYAN=`tput setaf 6`
RESETCOLOR=`tput sgr0`

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
		result=$(curl --connect-timeout 3 -s "http://"$SRV1""$PRT"/api/loader/status/sync" | jq '.syncing')
		sleep 2
	done

	date +"%Y-%m-%d %H:%M:%S || Looks like blockchain is finished syncing."
}
#---------------------------------------------------------------------------


while true;
do
	## Get forging status of server
	FORGE=$(curl --connect-timeout 1 -s "http://"$SRV1""$PRT"/api/delegates/forging/status?publicKey="$pbk| jq '.enabled')
	if [[ "$FORGE" == "true" ]]; ## Only check log and try to switch forging if needed, if server is currently forging
	then
		## Log when a block is forged
		FORGEDBLOCKLOG=$(tail ~/lisk-main/logs/lisk.log -n 20| grep 'Forged new block')
		if [[ -n "$FORGEDBLOCKLOG" ]];
		then
			date +"%Y-%m-%d %H:%M:%S || ${GREEN}$FORGEDBLOCKLOG${RESETCOLOR}"
		fi
		## Get current server's height and consensus
		SERVERLOCAL=$(curl --connect-timeout 1 --retry 3 --retry-delay 0 --retry-max-time 3 -s "http://"$SRV1""$PRT"/api/loader/status/sync")
		HEIGHTLOCAL=$( echo "$SERVERLOCAL" | jq '.height')
		CONSENSUSLOCAL=$( echo "$SERVERLOCAL" | jq '.consensus')

		## If consensus is less than 51 and we are forging soon, try a reload to get new peers
		## Management script should switch forging server during reload
		## from Nerigal
		if [ "$CONSENSUSLOCAL" -lt "51" ];
		then
			delegates=$(curl --connect-timeout 3 -s "http://"$SRV1""$PRT"/api/delegates/getNextForgers" | jq '.delegates')
			date +"%Y-%m-%d %H:%M:%S || ${YELLOW}Low consensus of $CONSENSUSLOCAL.  Looking for delegate forging soon matching $pbk${RESETCOLOR}"
			if [[ $delegates == *"$pbk"* ]];
			then
				date +"%Y-%m-%d %H:%M:%S || ${RED}You are forging in next 100 seconds, but your consensus is too low. Looking to switch server before reload.${RESETCOLOR}"
				for SERVER in ${SERVERS[@]}
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
							date +"%Y-%m-%d %H:%M:%S || ${CYAN}Switching to Server $SERVER with a consensus of $CONSENSUS as your consensus is too low.  We will try a reload.${RESETCOLOR}"
							ChangeDirectory
							bash lisk.sh reload
							sleep 20
							SyncState
							break
						else
							date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to disable forging on $SRV1 with low consensus before forging${RESETCOLOR}"
						fi
					fi
				done
			fi
		fi
		## Check log if node is recovering close to forging time
		LASTLINE=$(tail ~/lisk-main/logs/lisk.log -n 10| grep 'starting recovery')
		if [[ -n "$LASTLINE" ]];
		then
			delegates=$(curl --connect-timeout 3 -s "http://"$SRV1""$PRT"/api/delegates/getNextForgers" | jq '.delegates')
			date +"%Y-%m-%d %H:%M:%S || ${YELLOW}Node is recovering.  Looking for delegate forging soon matching $pbk${RESETCOLOR}"
			if [[ $delegates == *"$pbk"* ]];
			then
			date +"%Y-%m-%d %H:%M:%S || ${RED}You are forging soon, but your node is recovering. Looking to switch server while recovering.${RESETCOLOR}"
				for SERVER in ${SERVERS[@]}
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

		## Check log for Inadequate consensus
		LASTLINE=$(tail ~/lisk-main/logs/lisk.log -n 10| grep 'Inadequate')
		if [[ -n "$LASTLINE" ]];
		then
			date +"%Y-%m-%d %H:%M:%S || ${RED}WARNING: $LASTLINE${RESETCOLOR}"

			## for SERVER in ${SERVERS[@]}
			## do
				## Get next server's height and consensus
				## SERVERINFO=$(curl --connect-timeout 1 --retry 3 --retry-delay 0 --retry-max-time 3 -s -S "http://"$SERVER""$PRT"/api/loader/status/sync")
				## HEIGHT=$( echo "$SERVERINFO" | jq '.height')
				## CONSENSUS=$( echo "$SERVERINFO" | jq '.consensus')

				## Make sure next server is not more than 3 blocks behind this server and consensus is better, then switch
				## if [[  -n "$HEIGHT" ]];
				## then
				## 	diff=$(( $HEIGHTLOCAL - $HEIGHT ))
				## else
				## 	diff="999"
				## fi
				## if [ "$diff" -lt "3" ] && [ "$CONSENSUS" -gt "$CONSENSUSLOCAL" ]; ## Removed for now as I believe consensus read from API isn't updated every second to be fully accurate
				## if [ "$diff" -lt "3" ]; 
				## then
					DISABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 3 --retry-delay 0 --retry-max-time 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SRV1""$PRTS"/api/delegates/forging/disable | jq '.success')
					if [ "$DISABLEFORGE" = "true" ];
					then
						for SERVER in ${SERVERS[@]}
						do
							ENABLEFORGE=$(curl -s -S --connect-timeout 1 --retry 2 --retry-delay 0 --retry-max-time 2 -k -H "Content-Type: application/json" -X POST -d '{"secret":"'"$SECRET"'"}' https://"$SERVER""$PRTS"/api/delegates/forging/enable | jq '.success')
							if [ "$ENABLEFORGE" = "true" ];
							then
								date +"%Y-%m-%d %H:%M:%S || ${CYAN}Switching to Server $SERVER with a consensus of $CONSENSUS to try and forge.${RESETCOLOR}"
								break ## Leave servers loop
							else
								date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to enable forging on $SERVER.  Trying next server.${RESETCOLOR}"
							fi
						done
					else
						date +"%Y-%m-%d %H:%M:%S || ${RED}Failed to disable forging on $SRV1.${RESETCOLOR}"
					fi
					break
				## fi
			## done
		fi
		(( ++TXTDELAY ))
		if [[ "$TXTDELAY" -eq "60" ]];  ## Wait 30 seconds to update running status to not overcrowd log
		then
			date +"%Y-%m-%d %H:%M:%S || ${GREEN}Still working at block $HEIGHTLOCAL with a consensus of $CONSENSUSLOCAL${RESETCOLOR}"
			TXTDELAY=0
		fi
			sleep 0.5
	else
		(( ++TXTDELAY ))
		if [[ "$TXTDELAY" -eq "30" ]];  ## Wait 30 seconds to update running status to not overcrowd log
		then
			date +"%Y-%m-%d %H:%M:%S || This server is not forging"
			TXTDELAY=0
		fi
			sleep 1
	fi
done
