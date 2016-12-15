## Version 0.9.0
#!/bin/bash
SECRET="\"YOUR PASSPHRASE\""
SRV1="localhost"
PRT=":8000" 			# 7000 on testnet, 8000 on mainnet
PRTS=":2443"			# https port used to send secret
pbk="YOUR PUBLIC KEY"
SERVERS=(			# Array of servers to check in order
	  xxx.xxx.xxx.xxx
	  xxx.xxx.xxx.xxx
	  ...
	)

TXTDELAY=0
while true;
do
	## Get forging status of server
	FORGE=$(curl --connect-timeout 3 -s "http://"$SRV1""$PRT"/api/delegates/forging/status?publicKey="$pbk| jq '.enabled')
	if [[ "$FORGE" == "true" ]]; ## Only check log and try to switch forging if needed, if server is currently forging
	then
		## Get current server's height and consensus
		SERVERLOCAL=$(curl --connect-timeout 3 -s "http://"$SRV1""$PRT"/api/loader/status/sync")
		HEIGHTLOCAL=$( echo "$SERVERLOCAL" | jq '.height')
		CONSENSUSLOCAL=$( echo "$SERVERLOCAL" | jq '.consensus')
		
		## Check log for Inadequate consensus
		LASTLINE=$(tail ~/lisk-main/logs/lisk.log -n 2| grep 'Inadequate')
		if [[ -n "$LASTLINE" ]]
		then
			date +"%Y-%m-%d %H:%M:%S || WARNING: $LASTLINE"
		
			for SERVER in ${SERVERS[@]}
			do
				## Get next server's height and consensus
				SERVERINFO=$(curl --connect-timeout 3 -s "http://"$SERVER""$PRT"/api/loader/status/sync")
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
					curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV1""$PRTS"/api/delegates/forging/disable
					curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SERVER""$PRTS"/api/delegates/forging/enable
					echo
					date +"%Y-%m-%d %H:%M:%S || Switching to Server $SERVER with a consensus of $CONSENSUS to try and forge"
					break
				fi
			done
		fi
		(( ++TXTDELAY ))
		if [[ "$TXTDELAY" -eq "60" ]];  ## Wait 60 seconds to update running status to not overcrowd log
		then
			date +"%Y-%m-%d %H:%M:%S || Still working at block $HEIGHTLOCAL with a consensus of $CONSENSUSLOCAL"
			TXTDELAY=0
		fi
			sleep 1
	else
		(( ++TXTDELAY ))
		if [[ "$TXTDELAY" -eq "60" ]];  ## Wait 60 seconds to update running status to not overcrowd log
		then
			date +"%Y-%m-%d %H:%M:%S || This server is not forging"
			TXTDELAY=0
		fi
			sleep 1
	fi
done
