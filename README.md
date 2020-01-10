Simple tool to summarize the network-traffic-stats  
provided by the tool 'sar' (system activity report).   

sar has to be installed and activated, otherwise this
script won't work as expected.

See the script itself for further infos or use  
```
<scriptname> -h  
```
for usage-infos.

```
check_networktraffic.sh -h

# Output:

This script checks for network-interface-statistics
provided by the tool 'sar', which has to be installed previously.

Usage: 
./check_networktraffic.sh 
Arguments (all arguments are optional)
  -w: Warning incoming traffic      # default: empty string = all values are OK
  -W: Warning outgoing traffic      # default: empty string = all values are OK
  -c: Critical incoming traffic     # default: empty string = all values are OK
  -C: Critical outgoing traffic     # default: empty string = all values are OK
  -d: Interval in minutes to check  # default: 20 = 20 Minutes
  -i: String of interfaces,         # default: empty string = all interfaces 
                                    #                         which are found
                                    #                         seperated by space.
```
