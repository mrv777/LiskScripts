# Lisk Delegate Scripts  (BETA)

## My consensus check script

### check_consensus.sh
This script looks at the last two lines of the log: ~/lisk-main/logs/lisk.log for the word 'Inadequate'.  If it sees that word then it tries to swtich forging quickly to server 2.  If server two is not at a good height, it tries server 3 if available

## My Anti-fork script

How to run:

1. sudo apt-get install jq
2. wget https://lisktools.io/backups/init_height_and_rebuild.sh
3. bash init_height_and_rebuild.sh start

### init_height_and_rebuild.sh
Wrapper script for check_height_and_rebuild.sh.  You only need to use this script directly and not check_height_and_rebuild.sh.  Commands are:
* start         -- starts script
* stop          -- stops script
* upgrade       -- upgrades and runs script

### check_height_and_rebuild.sh
**User does not need to directly do anything with this.  init_height_and_rebuild.sh interfaces with it automatically**

Compares the height of your 100 connected peers and gets the highest height.  Then checks your node is within 4 blocks of it.  If not, it tries a rebuild.  If the rebuild only gets it further away, it tries a rebuild.  The rebuild attempts to get the newest snap availble from servers listed. 

**NOTE: The is currently not the best.  Howver, it's better because it now looks for the most recently modified file and the biggest file.  It should look for the highest block though.**

## My Management script

### manage3.sh
This script will check the block heights of 3 servers and make sure the one forging is near the top height of the 3, if not it switches to the next server (1->2,2->3,3->1).  It also makes sure only one server is forging.

Currently designed to run in a screen on it's own monitoring server.  Just fill in the top variable in the script and then run it `bash manage3.sh`
