#!/bin/bash
SECRET="\"YOUR PASSPHRASE\""
SRV1="localhost"
SRV2="xxx.xxx.xxx.xxx"
SRV3=""
PRTS=":2443"
while true; do
	LASTLINE=$(tail ~/lisk-main/logs/lisk.log -n 2| grep 'Inadequate')
	if [[ -n "$LASTLINE" ]]
	then
		HEIGHTLOCAL=$(curl --connect-timeout 3 -s "http://"$SRV1":8000/api/loader/status/sync"| jq '.height')
		HEIGHT=$(curl --connect-timeout 3 -s "https://"$SRV2""$PRTS"/api/loader/status/sync"| jq '.height')
		
		## Make sure second server is not more than 3 blocks behind this server and if not, then switch
		diff=$(( $HEIGHT - $HEIGHTLOCAL ))
		if [[ "$diff" -lt "3" ]]
		then
			curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV1""$PRTS"/api/delegates/forging/disable
			curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV2""$PRTS"/api/delegates/forging/enable
			echo
			echo "Switching to Server 2 to try and forge"
			sleep 3
		elif [[  -n "$SRV3" ]] ## If a third server is set, try that one
		then
			HEIGHT=$(curl --connect-timeout 3 -s "https://"$SRV3""$PRTS"/api/loader/status/sync"| jq '.height')
			diff=$(( $HEIGHT - $HEIGHTLOCAL ))
			if [[ "$diff" -lt "3" ]]
			then
				curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV1""$PRTS"/api/delegates/forging/disable
				curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' https://"$SRV3""$PRTS"/api/delegates/forging/enable
				echo
				echo "Switching to Server 3 to try and forge"
				sleep 3
			fi
		fi
	fi
    echo "Everything is Okay"
    sleep 1
done
