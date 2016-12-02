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

SRV=127.0.0.1:8000
LISK_DIR="~/lisk-main/"

find_newest_snap_rebuild(){
	## Find newest snapshot
	## isabella
	SNAP1URL="https://snapshot.liskwallet.net"
	SNAP1="https://snapshot.liskwallet.net/blockchain.db.gz"
	SNAP1TIME=$(curl -sI "$SNAP1" | grep Last-Modified | cut -f2- -d:)
	SNAP1TIME=$(date -d "$SNAP1TIME" +"%s")

	## Gr33nDrag0n
	SNAP2URL="https://snapshot.lisknode.io"
	SNAP2="https://snapshot.lisknode.io/blockchain.db.gz"
	SNAP2TIME=$(curl -sI "$SNAP2" | grep Last-Modified | cut -f2- -d:)
	SNAP2TIME=$(date -d "$SNAP2TIME" +"%s")

	## MrV
	SNAP3URL="https://lisktools.io/backups"
	SNAP3="https://lisktools.io/backups/blockchain.db.gz"
	SNAP3TIME=$(curl -sI "$SNAP3" | grep Last-Modified | cut -f2- -d:)
	SNAP3TIME=$(date -d "$SNAP3TIME" +"%s")
	
	## Official
	SNAP4URL="https://downloads.lisk.io/lisk/main"
	SNAP4="https://downloads.lisk.io/lisk/main/blockchain.db.gz"
	SNAP4TIME=$(curl -sI "$SNAP4" | grep Last-Modified | cut -f2- -d:)
	SNAP4TIME=$(date -d "$SNAP4TIME" +"%s")
	
	## punkrock
	SNAP5URL="https://snapshot.punkrock.me"
	SNAP5="https://snapshot.punkrock.me/blockchain.db.gz"
	SNAP5TIME=$(curl -sI "$SNAP5" | grep Last-Modified | cut -f2- -d:)
	SNAP5TIME=$(date -d "$SNAP5TIME" +"%s")
	
	## redsn0w
	SNAP6URL="https://snapshot.lsknode.org"
	SNAP6="https://snapshot.lsknode.org/blockchain.db.gz"
	SNAP6TIME=$(curl -sI "$SNAP6" | grep Last-Modified | cut -f2- -d:)
	SNAP6TIME=$(date -d "$SNAP6TIME" +"%s")
	

	SNAPURL=$SNAP1URL
	SNAP=$SNAP1
	SNAPTIME=$SNAP1TIME
	## echo "$SNAP2TIME - $SNAPTIME" 
	if [ "$SNAP2TIME" -gt "$SNAPTIME" ]; 
	then
		SNAPURL=$SNAP2URL
		SNAP=$SNAP2
		SNAPTIME=$SNAP2TIME
	fi

	##echo "$SNAP3TIME - $SNAPTIME" 
	if [ "$SNAP3TIME" -gt "$SNAPTIME" ]; 
	then
		SNAPURL=$SNAP3URL
		SNAP=$SNAP3
		SNAPTIME=$SNAP3TIME
	fi
	
	if [ "$SNAP4TIME" -gt "$SNAPTIME" ]; 
	then
		SNAPURL=$SNAP4URL
		SNAP=$SNAP4
		SNAPTIME=$SNAP4TIME
	fi
	
	if [ "$SNAP5TIME" -gt "$SNAPTIME" ]; 
	then
		SNAPURL=$SNAP5URL
		SNAP=$SNAP5
		SNAPTIME=$SNAP5TIME
	fi
	
	if [ "$SNAP6TIME" -gt "$SNAPTIME" ]; 
	then
		SNAPURL=$SNAP6URL
		SNAP=$SNAP6
		SNAPTIME=$SNAP6TIME
	fi
	
	echo "Newest snap: $SNAP | Rebuilding from it..."
	#bash lisk.sh stop ## Trying to figure out why rebuilding from block 0.  Attempting to stop first to make sure the DB shuts down too
	#sleep 2
	bash lisk.sh rebuild -u $SNAPURL
}

top_height(){
	## Get height of your 100 peers and save the highest value
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
		cd $LISK_DIR
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
			## Thank you corsaro for this improvement :)
			while true; do
				s1=`curl -k -s "http://$SRV/api/loader/status/sync"| jq '.height'`
				sleep 60
				s2=`curl -k -s "http://$SRV/api/loader/status/sync"| jq '.height'`

				diff=$(( $s2 - $s1 ))
				if [ "$diff" -gt "10" ];
				then
					echo "$s2" "is too greater then " "$s1"
					echo "It looks like rebuild has not finished yet. Waiting longer to continue"
				else
					echo "" "$s1" " " "$s2"
					echo "Looks like rebuilding finished. We can stop this"
					break
				fi
			done
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
