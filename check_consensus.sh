#!/bin/bash
SECRET="\"YOUR PASSPHRASE\""
SRV1="localhost"
SRV2="xxx.xxx.xxx.xxx"
SRV3=""
PRTS=":2443"
while true; do
	LASTLINE=$(tail ~/lisk-main/logs/lisk.log -n 2| grep 'Inadequate')
	HEIGHTLOCAL=$(curl --connect-timeout 3 -s "http://"$SRV1":8000/api/loader/status/sync"| jq '.height')
	if [[ -n "$LASTLINE" ]]
	then
		HEIGHT=$(curl --connect-timeout 3 -s "http://"$SRV2":8000/api/loader/status/sync"| jq '.height')
		
		## Make sure second server is not more than 3 blocks behind this server and if not, then switch
		if [[  -n "$HEIGHT" ]];
		then
			diff=$(( $HEIGHTLOCAL - $HEIGHT ))
		else
			diff="999"
		fi
		if [[ "$diff" -lt "3" ]]
		then
			curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV1""$PRTS"/api/delegates/forging/disable
			curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV2""$PRTS"/api/delegates/forging/enable
			echo
			echo "Switching to Server 2 to try and forge"
			sleep 2
		elif [[  -n "$SRV3" ]] ## If a third server is set, try that one
		then
			HEIGHT=$(curl --connect-timeout 3 -s "http://"$SRV3":8000/api/loader/status/sync"| jq '.height')

			if [[  -n "$HEIGHT" ]];
			then
				diff=$(( $HEIGHTLOCAL - $HEIGHT ))
			else
				diff="999"
			fi
			if [[ "$diff" -lt "3" ]]
			then
				curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV1""$PRTS"/api/delegates/forging/disable
				curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV3""$PRTS"/api/delegates/forging/enable
				echo
				echo "Switching to Server 3 to try and forge"
				sleep 2
			fi
		fi
	fi
    echo -ne "$HEIGHTLOCAL | "
    sleep 1
done
