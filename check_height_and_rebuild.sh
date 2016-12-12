## check_height_and_rebuild.sh
## Version 0.8.0
## Tested with jq 1.5.1 on Ubuntu 16.04.1
## 
## Current snapshot sources and creation times
## 00:00 & 12:00 UTC (isabella)
## ----- & 15:00 UTC (punkrock)
## 01:00, 05:00, 09:00, 13:00, 17:00, 21:00 UTC (Gr33nDrag0n)
## 03:00, 07:00, 11:00, 15:00, 19:00, 23:00 UTC (MrV)
## ----- & ----- UTC(redsn0w)
#!/bin/bash

# gregorst
if [[ "$EUID" -eq 0 ]];
then
  echo "Error: Do not run this as root. Exiting."
  exit 1
fi

##SECRET="\"YOUR PASSPHRASE\"" ## Uncomment this line if you want this script to reenable forging when done
SRV=127.0.0.1:8000

## Make sure we are in the correct directory (corsaro suggestion)
function ChangeDirectory(){
	cd ~
	cd ~/lisk-main  ## Set to your lisk directory if different
}

#---------------------------------------------------------------------------
# Looping while node is building blockchain 
# from Nerigal
function SyncState()
{
	result='true'
	while [ $result == 'true' ]
	do
		echo "Blockchain syncing"
		result=`curl -s "http://$SRV/api/loader/status/sync"| jq '.syncing'`
		sleep 2
	done
	
	echo "Looks like rebuilding finished."
	if [[ -z "$SECRET" ]];
	then
		curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' http://"$SRV"/api/delegates/forging/enable ## If you want this script to reenable forging when done
	fi
}
#---------------------------------------------------------------------------


## Thanks to cc001 and hagie for improvements here and cc001 for comparing blocks instead of size and timestamp
find_newest_snap_rebuild(){

	SNAPSHOTS=(
	  https://downloads.lisk.io/lisk/main		## Official
	  https://snapshot.liskwallet.net			## isabella
	  https://snapshot.lisknode.io				## Gr33nDrag0n
	  https://lisktools.io/backups/index.php	## MrV
	  https://snapshot.punkrock.me				## punkrock
	  https://snap.lsknode.org					## redsn0w
	)
	
	MATCHER="lisk_main_backup-[0-9]*\.gz"

	BESTSNAP=""
	BESTSNAPBLOCK=0
	
	BESTSNAP2=""
	BESTSNAPBLOCK2=0
	
	for SNAPSHOT in ${SNAPSHOTS[@]}
	do
	  BACKUP=`curl -s $SNAPSHOT | grep -o "$MATCHER" | sort | tail -n 1`
	  BLOCK=`echo $BACKUP | grep -oh "[0-9]*"`
	  echo "$SNAPSHOT"
	  echo "$BLOCK"
	  if [ -z "$BLOCK" ];
	  then
	  	echo "Couldn't locate block number"
	  else
		  if [ "$BLOCK" -gt "$BESTSNAPBLOCK" ];
		  then
			BESTSNAPBLOCK2=$BESTSNAPBLOCK
			BESTSNAP2=$BESTSNAP
		
			BESTSNAPBLOCK=$BLOCK
			BESTSNAP=$SNAPSHOT
		  elif [ "$BLOCK" -gt "$BESTSNAPBLOCK2" ]; ## Check if the second is newer
		  then	 
		  	 BESTSNAPBLOCK2=$BLOCK
			 BESTSNAP2=$SNAPSHOT
		  fi
	  fi
	  echo ""
	done
	
	## Randomly choose between the best 2 snapshots to prevent everyone downloading from the same source
	WHICHSNAP=$((1 + RANDOM % 2))
    	
	ChangeDirectory ## Make sure we are in the correct directory
	if [ "$WHICHSNAP" -eq "1" ];
	then
		echo "Newest snap: $BESTSNAP at block: $BESTSNAPBLOCK"
    		bash lisk.sh rebuild -u $BESTSNAP
	else
		echo "Newest snap: $BESTSNAP2 at block: $BESTSNAPBLOCK2"
    		bash lisk.sh rebuild -u $BESTSNAP2
	fi
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
		ChangeDirectory ## Make sure we are in the correct directory
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
			sleep 30
			SyncState
			#sleep 420
			## Thank you corsaro for this improvement
			## while true; do
			## 	s1=`curl -k -s "http://$SRV/api/loader/status/sync"| jq '.height'`
			## 	sleep 30
			## 	s2=`curl -k -s "http://$SRV/api/loader/status/sync"| jq '.height'`

			## 	diff=$(( $s2 - $s1 ))
			## 	if [ "$diff" -gt "5" ];
			## 	then
			## 		echo "$s2" "is a lot greater then " "$s1"
			## 		echo "It looks like rebuild has not finished yet. Waiting longer to continue"
			## 	else
			## 		echo "" "$s1" " " "$s2"
			## 		echo "Looks like rebuilding finished. We can stop this"
			## 		if [[ -z "$SECRET" ]];
			## 		then
			## 			curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' http://"$SRV"/api/delegates/forging/enable ## If you want this script to reenable forging when done
			## 		fi
			## 		break
			## 	fi
			## done
		else
			if [[ -z "$SECRET" ]];
			then
				curl --connect-timeout 3 -k -H "Content-Type: application/json" -X POST -d '{"secret":'"$SECRET"'}' http://"$SRV"/api/delegates/forging/enable ## Uncomment this line if you want this script to reenable forging when done
			fi
		fi
	fi
}
cd ~/lisk-main/  ## Set to your lisk directory if different
while true; do
	## Check that lisk is running first!!
	STATUS="$(bash lisk.sh status | grep 'Lisk is running as PID')"
	if [[ -z "$STATUS" ]];
	then
		bash lisk.sh stop
		sleep 2 
		bash lisk.sh start
		sleep 2
	fi
	
	top_height
	local_height

	echo "Local: $CHECKSRV, Highest: $HEIGHT, Diff: $diff"
	sleep 10
done
