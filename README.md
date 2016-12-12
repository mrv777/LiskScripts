# Lisk Delegate Scripts  (BETA)

## Thank you
Thank you to cc001, corsaro, liberspirita, wannabe_RoteBaron, hagie, isabella, Nerigal, and anyone I might have missed for their help and/or contributions.

## My consensus check script

### check_consensus.sh
This script looks at the last two lines of the log: ~/lisk-main/logs/lisk.log for the word 'Inadequate'.  If it sees that word then it tries to swtich forging quickly to server 2.  If server two is not at a good height, it tries server 3 if available.  You can run this on all forging servers.

#### How to test:
If you enter `"Inadequate" >> ~/lisk-main/log/lisk.log` on the server, it should activate check_consensus.sh to switch forging nodes

## My Anti-fork script

#### How to run:

1. `sudo apt-get install jq`
2. `wget https://lisktools.io/backups/init_height_and_rebuild.sh`
3. `bash init_height_and_rebuild.sh start`

To check the logs and what the script is going:

* `tail -f heightRebuild.log`

### init_height_and_rebuild.sh
Wrapper script for check_height_and_rebuild.sh.  You can run this on all forging servers.  You only need to use this script directly and not check_height_and_rebuild.sh.  Commands are:
* start         -- starts script
* stop          -- stops script
* upgrade       -- upgrades and runs script

### check_height_and_rebuild.sh
**User does not need to directly do anything with this.  init_height_and_rebuild.sh interfaces with it automatically**

Compares the height of your 100 connected peers and gets the highest height.  Then checks your node is within 4 blocks of it.  If not, it tries a reload first.  If the reload doesn't get it back within an acceptable range, it tries a rebuild.  The rebuild attempts to get the newest snap availble from servers listed. 

**NOTE: The is currently not the best.  However, it's better because it now looks for the most recently modified file and the biggest file.  It should look for the highest block though.**

## My Management script

### manage3.sh
This script will check the block heights of 3 servers and make sure the one forging is near the top height of the 3, if not it switches to the next server (1->2,2->3,3->1).  It also makes sure only one server is forging.

Currently designed to run in a screen on it's own monitoring server.

#### How to run:

1. `sudo apt-get install jq screen`
2. `wget https://raw.githubusercontent.com/mrv777/LiskScripts/master/manage3.sh`
3. `nano manage3.sh` and edit the top variables
4. `screen`
5. `bash manage3.sh`
6. CTRL+A, D to detach the screen

*Donation Address: 3532362465127676136L*
