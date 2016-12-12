## Version 0.8.0
#!/bin/bash
SECRET="\"YOUR PASSPHRASE\""
SRV1="localhost"
SRV2="xxx.xxx.xxx.xxx"
SRV3=""			# Leave blank if only using 2 servers
PRT1=":8000" 	# 7000 on testnet, 8000 on mainnet
PRTS=":2443"	# port used on https
pbk="YOUR PUBLIC KEY"

TXTDELAY=0
while true; do
	## Get forging status of server
	FORGE=$(curl --connect-timeout 3 -s "http://"$SRV1""$PRT1"/api/delegates/forging/status?publicKey="$pbk| jq '.enabled')
	if [[ "$FORGE" == "true" ]]; ## Only check log and try to switch forging if needed, if server is currently forging
	then
		LASTLINE=$(tail ~/lisk-main/logs/lisk.log -n 2| grep 'Inadequate')
		HEIGHTLOCAL=$(curl --connect-timeout 3 -s "http://"$SRV1":8000/api/loader/status/sync"| jq '.height')
		if [[ -n "$LASTLINE" ]]
		then
			HEIGHT=$(curl --connect-timeout 2 -s "http://"$SRV2":8000/api/loader/status/sync"| jq '.height')
			CONSENSUS=$(curl --connect-timeout 2 -s "http://"$SRV2":8000/api/loader/status/sync"| jq '.consensus')
			echo "WARNING: $LASTLINE"
		
			## Make sure second server is not more than 3 blocks behind this server and consensus is good, then switch
			if [[  -n "$HEIGHT" ]];
			then
				diff=$(( $HEIGHTLOCAL - $HEIGHT ))
			else
				diff="999"
			fi
			if [ "$diff" -lt "3" ] && [ "$CONSENSUS" -gt "50" ]; 
			then
				curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV1""$PRTS"/api/delegates/forging/disable
				curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV2""$PRTS"/api/delegates/forging/enable
				echo
				echo "Switching to Server 2 to try and forge"
				## sleep 2 ## Shouldn't be needed any longer since we check forging status at start
			elif [[  -n "$SRV3" ]] ## If a third server is set, try that one
			then
				HEIGHT=$(curl --connect-timeout 2 -s "http://"$SRV3":8000/api/loader/status/sync"| jq '.height')
				CONSENSUS=$(curl --connect-timeout 2 -s "http://"$SRV3":8000/api/loader/status/sync"| jq '.consensus')

				if [[  -n "$HEIGHT" ]];
				then
					diff=$(( $HEIGHTLOCAL - $HEIGHT ))
				else
					diff="999"
				fi
				if [ "$diff" -lt "3" ] && [ "$CONSENSUS" -gt "50" ]; 
				then
					curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV1""$PRTS"/api/delegates/forging/disable
					curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV3""$PRTS"/api/delegates/forging/enable
					echo
					echo "Switching to Server 3 to try and forge"
					## sleep 2 ## Shouldn't be needed any longer since we check forging status at start
				else
					echo "No better server to switch to"
				fi
			else
				echo "No better server to switch to"
			fi
		fi
		(( ++TXTDELAY ))
		if [[ "$TXTDELAY" -eq "60" ]];  ## Wait 60 seconds to update running status to not overcrowd log
		then
			echo "Still working at block $HEIGHTLOCAL"
			TXTDELAY=0
		fi
			sleep 1
	else
		(( ++TXTDELAY ))
		if [[ "$TXTDELAY" -eq "60" ]];  ## Wait 60 seconds to update running status to not overcrowd log
		then
			echo "This server is not forging"
			TXTDELAY=0
		fi
			sleep 1
	fi
done
