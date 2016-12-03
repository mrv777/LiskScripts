## check_height_and_rebuild.sh
## Tested with jq 1.5.1 on Ubuntu 16.04.1
## 
## Current snapshot sources and creation times
## 00:00 & 12:00 UTC (isabella)
## ----- & 15:00 UTC (punkrock)
## 05:00 & 17:00 UTC (Gr33nDrag0n)
## 09:00 & 21:00 UTC (MrV)
## ----- & ----- UTC(redsn0w)
#!/bin/bash

##SECRET="\"YOUR PASSPHRASE\"" ## Uncomment this line if you want this script to reenable forging when done
SRV=127.0.0.1:8000

## Thanks to cc001 and hagie for improvements here
find_newest_snap_rebuild(){

	SNAPSHOTS=(
	  https://downloads.lisk.io/lisk/main/blockchain.db.gz	## Official
	  https://snapshot.liskwallet.net/blockchain.db.gz		## isabella
	  https://snapshot.lisknode.io/blockchain.db.gz			## Gr33nDrag0n
	  https://lisktools.io/backups/blockchain.db.gz			## MrV
	  https://snapshot.punkrock.me/blockchain.db.gz			## punkrock
	  https://snap.lsknode.org/blockchain.db.gz			## redsn0w
	)

	BESTSNAP=""
	BESTTIMESTAMP=0
	BESTSNAPLENGTH=0

	for SNAP in ${SNAPSHOTS[@]}
	do
	  echo "$SNAP"
	  SNAPSTATUS=$(curl -sI "$SNAP" | grep "HTTP" | cut -f2 -d" ")
	  SNAPLENGTH=$(curl -sI "$SNAP" | grep "Length" | cut -f2 -d" ")
	  SNAPLENGTH="${SNAPLENGTH//[$'\t\r\n ']}"
	  if [ "$SNAPSTATUS" -eq "200" ]
	  then
		  TIME=$(curl -sI "$SNAP" | grep Last-Modified | cut -f2 -d:)
		  TIMESTAMP=$(date -d "$TIME" +"%s")
		  echo $TIMESTAMP
		  if [ "$TIMESTAMP" -gt "$BESTTIMESTAMP" ] && [ "$SNAPLENGTH" -gt "$BESTSNAPLENGTH" ]; ## Make sure it is the newest and the largest
		  then
			 BESTSNAP=$SNAP
			 BESTTIMESTAMP=$TIMESTAMP
			 BESTSNAPLENGTH=$SNAPLENGTH
		  fi
	   fi
	done
    
    REPO=${BESTSNAP%/blockchain.db.gz}
	echo "Newest snap: $BESTSNAP | Rebuilding from $REPO"

    ## bash lisk.sh stop ## Trying to figure out why rebuilding from block 0.  Attempting to stop first to make sure the DB shuts down too
    ## sleep 5
    bash lisk.sh rebuild -u $REPO
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
	if [ "$diff" -gt "4" ]
	then
        echo "Reloading! Local: $CHECKSRV, Highest: $HEIGHT, Diff: $diff"
		cd ~/lisk-main/
		bash lisk.sh reload
		sleep 60
		
		## Make sure local height is not empty, if it is empty try the call until it is not empty
		CHECKSRV=`curl -s "http://$SRV/api/loader/status/sync"| jq '.height'`
		while [ -z "$CHECKSRV" ]
		do
    		sleep 1
			CHECKSRV=`curl -s "http://$SRV/api/loader/status/sync"| jq '.height'`
		done
		
		## Rebuild if still out of sync after reload
		diff=$(( $HEIGHT - $CHECKSRV ))
		if [ "$diff" -gt "6" ]
		then
			echo "Rebuilding! Local: $CHECKSRV, Highest: $HEIGHT, Diff: $diff"
			find_newest_snap_rebuild
			#sleep 420
			## Thank you corsaro for this improvement
			while true; do
				s1=`curl -k -s "http://$SRV/api/loader/status/sync"| jq '.height'`
				sleep 60
				s2=`curl -k -s "http://$SRV/api/loader/status/sync"| jq '.height'`

				diff=$(( $s2 - $s1 ))
				if [ "$diff" -gt "10" ];
				then
					echo "$s2" "is a lot greater then " "$s1"
					echo "It looks like rebuild has not finished yet. Waiting longer to continue"
				else
					echo "" "$s1" " " "$s2"
					echo "Looks like rebuilding finished. We can stop this"
					##curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' http://"$SRV"/api/delegates/forging/enable ## Uncomment this line if you want this script to reenable forging when done
					break
				fi
			done
		##else ## Uncomment this line if you want this script to reenable forging when done
			##curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' http://"$SRV"/api/delegates/forging/enable ## Uncomment this line if you want this script to reenable forging when done
		fi
	fi
}

while true; do
	## Check that lisk is running first!!
	top_height
	local_height

	echo "Local: $CHECKSRV, Highest: $HEIGHT, Diff: $diff"
	sleep 10
done
