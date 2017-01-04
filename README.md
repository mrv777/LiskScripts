# Lisk Delegate Scripts  (BETA v0.9.4)

## Thank you
Thank you to cc001, corsaro, liberspirita, wannabe_RoteBaron, hagie, isabella, stoner19, punkrock, Nerigal, doweig, and anyone I might have missed for their help and/or contributions.

## Control Script
This is the wrapper script for check_height_and_rebuild.sh and check_consensus.sh.  You can run this on all forging servers.  You only need to use this script directly and not check_height_and_rebuild.sh or check_consensus.sh.  Commands are:
* start             -- starts both scripts
* startc            -- starts consensus script
* starth            -- starts height_rebuild script
* startm            -- starts management script
* stop              -- stops both scripts
* stopc             -- stops consensus script
* stoph             -- stops height_rebuild script
* logs              -- display all log files (requires multitail)
* upgrade           -- upgrades and runs runs both scripts

#### How to run:

1. `sudo apt-get install jq`
2. `wget https://raw.githubusercontent.com/mrv777/LiskScripts/master/control.sh`
3. Choose which scripts to run
  1. `bash control.sh start` - Both
  2. `bash control.sh startc` - Consensus script only
  3. `bash control.sh starth` - Rebuild script only

To check the logs and what the script is going:

* `tail -f heightRebuild.log`
* `tail -f consensus.log`
* `bash control.sh logs` (requires multitail)

## My consensus check script

### check_consensus.sh
**User does not need to directly do anything with this.  control.sh interfaces with it automatically**

This script looks at the last two lines of the log: ~/lisk-main/logs/lisk.log for the word 'Inadequate'.  If it sees that word then it tries to switch forging quickly to server 2.  If server two is not at a good height, it tries server 3 if available.  You can run this on all forging servers.

#### How to test:
If you enter `"Inadequate" >> ~/lisk-main/log/lisk.log` on the server, it should activate check_consensus.sh to switch forging nodes

## My Anti-fork script

### check_height_and_rebuild.sh
**User does not need to directly do anything with this.  control.sh interfaces with it automatically**

Compares the height of your 100 connected peers and gets the highest height.  Then checks your node is within 4 blocks of it.  If not, it tries a reload first.  If the reload doesn't get it back within an acceptable range, it tries a rebuild.  The rebuild attempts to get the newest snap available from servers listed. 

## My Management script

### manage.sh
**User does not need to directly do anything with this.  control.sh interfaces with it automatically**
This script will check the block heights of all listed servers.  It will attempt to have one and only one server forging and prefer to have server 1 do the forging.  If the forging server swtiches by something other then this script, it will pause for 15 seconds and then check the status of the servers after that.

#### How to run:

1. `sudo apt-get install jq`
2. `wget https://raw.githubusercontent.com/mrv777/LiskScripts/master/control.sh`
3. `bash control.sh startm` - Start management script

To check the logs and what the script is going:

* `tail -f manage.log`
* `bash control.sh logs` (requires multitail)

*Donation Address: 3532362465127676136L*
