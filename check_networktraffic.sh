#!/usr/bin/env bash

# This script is tested in a bash-environment.
# Changes are required, if you use another shell.
#
# ---------------------------------------------------------------------
# See: https://github.com/jayjensen/monitoring-scripts/network_traffic_based_on_sar
# ---------------------------------------------------------------------
#                                Infos
# ---------------------------------------------------------------------
# Prerequisites :
# ----------------
# sar (system activity report) - has to be installed, activated and configured.
# e.g. for Ubuntu: Package "sysstat". 
# Please make sure, that the provided stats fit your needs.
#
# Purpose: 
# ---------------
# This script collects the networktraffic-stats of the 
# specified period and interfaces and aggregates them.
# If no interfaces are specified, all interfaces are used.
# The "lo" Interface is omitted.
# It does not seem to be a good idea to not specify the interfaces,
# especially when many interfaces of internal use are present,
# for example if dockerd is running.
# 
# Attention:
# ---------------
# Missing values for warning and critical are assumed as "OK",
# which means that are not checked, which gives them an informational
# character.
#
# Additional notes:
# ---------------
# I:   root-permissions for sar respectively this script should not be required
# II:  it might be required to a) either set the locale or
#                              b) change the "grepped" value in function
#                                 get_interface_stats() to meet your requirements
#                                 (see below)
# III: after installation and activation, sar (sysstat) needs some minutes to 
#      collect the first (required) data
#----------------------------------------------------------------------

# ---------------------------------------------------------------------
#                      Variables / default values
# ---------------------------------------------------------------------

# Predefined interval in minutes 
INTERVAL="20"

# interface statistics of the interval passed by variable
DATE=$(date --date '-'${INTERVAL}' min' +%H:%M:00)
# Remove whitespace from variable:
DATE=$(echo $DATE | sed -e 's/\d//')

INTERFACES=""

# exit Codes
OK=0
WARN=1
CRIT=2
UNKNOWN=3

# default values warning and crit
W_INC=""
W_OUT=""
C_INC=""
C_OUT=""

# default exit-code
EXITCODE=0

# ---------------------------------------------------------------------
#                             Functions
# ---------------------------------------------------------------------

function usage() {
  echo ""
  echo "This script checks for network-interface-statistics"
  echo "provided by the tool 'sar', which has to be installed previously."
  echo ""
  echo "Usage: "
  echo "${0} "
  echo "Arguments (all arguments are optional)"
  echo "  -w: Warning incoming traffic      # default: empty string = all values are OK"
  echo "  -W: Warning outgoing traffic      # default: empty string = all values are OK"
  echo "  -c: Critical incoming traffic     # default: empty string = all values are OK"
  echo "  -C: Critical outgoing traffic     # default: empty string = all values are OK"
  echo "  -d: Interval in minutes to check  # default: 20 = 20 Minutes"        
  echo "  -i: String of interfaces,         # default: empty string = all interfaces which are found"       
  echo "      seperated by space."
  
  exit ${UNKNOWN}
}

function preflight_check_sar() {
# check if "sar" is installed
  type sar &> /dev/null
  if [ ${?} -ne 0 ] ; then
    echo "'sar' command required but not found."
    echo "For example on Ubuntu: Package 'sysstat'."
    echo "Terminating script."
    exit ${UNKNOWN}
  fi
}

function preflight_check_interfaces() {
# check if submitted interfaces are present
  for interface in ${INTERFACES} ; do
    ip -o link | awk '{print $2}' | sed -e 's/://' | grep -q $interface
    if [ "${?}" -ne "0" ] ; then
      echo "The interface $interface does not exist. Exiting"
      exit ${UNKNOWN}
    fi
  done

}

function get_interface_stats() {
# returns the average traffic in KByte/s. 

  # Check sar installation
  preflight_check_sar
  
  # get interfaces if not specified
  if [ -z "${INTERFACES}" ] ; then
    for i in $(ip -o link | awk '{print $2}' | sed -e 's/://'); do
      if [ ${i} != "lo" ] ; then
        INTERFACES="${INTERFACES} $i"
      fi
    done
  else
    preflight_check_interfaces
  fi
  
  # Aggregates single interface traffic to total sum. 
  # Using awk for float-arithmetics. 
  # Fields: Interface;received(RX);transmitted(TX)
  RX_TOTAL=0
  TX_TOTAL=0
  for x in $INTERFACES; do
    data_returned=$(sar -n DEV -s ${DATE} | grep $x | grep -i -E 'average|durchsch' | awk '{print $2 "#" $5 "#" $6}')

    # ---------------------------------------------
    # RX part
    # ---------------------------------------------
    RXKB=$(echo $data_returned | cut -d '#' -f2)
  
    # ---------------------------------------------
    # TX part
    # ---------------------------------------------
    TXKB=$(echo $data_returned | cut -d '#' -f3)
 
    # summarize stats 
    RX_TOTAL=$(echo "$RX_TOTAL $RXKB" | awk '{ print $1 + $2}')
    TX_TOTAL=$(echo "$TX_TOTAL $TXKB" | awk '{ print $1 + $2}')
  done

  # --------------

  #        Check for warning and crit values

  # incoming traffic
  if [ -n "${C_INC}" ] ; then
    greater_than=$(awk -v returned="${RX_TOTAL}" -v limit="${C_INC}" 'BEGIN { print (returned >= limit) ? 0 : 1 }')
    if [ ${greater_than} -eq 0 ] ; then
      EXITCODE=${CRIT}
    fi
  fi
    
  if [ -n "${W_INC}" ] ; then
    greater_than=$(awk -v returned="${RX_TOTAL}" -v limit="${W_INC}" 'BEGIN { print (returned >= limit) ? 0 : 1 }')
    if [ ${greater_than} -eq 0 ] ; then
      EXITCODE=${WARN}
    fi
  fi

  # outgoing traffic
  if [ -n "${C_OUT}" ] ; then
    greater_than=$(awk -v returned="${TX_TOTAL}" -v limit="${C_OUT}" 'BEGIN { print (returned >= limit) ? 0 : 1 }')
    if [ ${greater_than} -eq 0 ] ; then
      EXITCODE=${CRIT}
    fi
  fi
    
  if [ -n "${W_OUT}" ] ; then
    greater_than=$(awk -v returned="${TX_TOTAL}" -v limit="${W_OUT}" 'BEGIN { print (returned >= limit) ? 0 : 1 }')
    if [ ${greater_than} -eq 0 ] ; then
      EXITCODE=${WARN}
    fi
  fi
  OUTPUT="Traffic in KB of last ${INTERVAL} minutes  |"
  OUTPUT="${OUTPUT} rx_kb=${RX_TOTAL};;;; tx_kb=${TX_TOTAL};;;;"
  
  echo "${OUTPUT}"
  
  exit $EXITCODE
}


# ---------------------------------------------------------------------
#                        Entrypoint
# ---------------------------------------------------------------------

while getopts ":w:W:c:C:d:i:h" opt; do
  case $opt in
    w)
      W_INC=${OPTARG}
      W_INC="$(printf '%d' ${W_INC} 2>/dev/null)"
      ;;
    W)
      W_OUT=${OPTARG}
      W_OUT="$(printf '%d' ${W_OUT} 2>/dev/null)"
      ;;
    c)
      C_INC=${OPTARG}
      C_INC="$(printf '%d' ${C_INC} 2>/dev/null)"
      ;;
    C)
      C_OUT=${OPTARG}
      C_OUT="$(printf '%d' ${C_OUT} 2>/dev/null)"
      ;;
    d)
      INTERVAL=${OPTARG}
      # remove Whitespace
      INTERVAL=$(echo ${INTERVAL} | sed -e 's/\d//')
      DATE=$(date --date '-'${INTERVAL}' min' +%H:%M:00)
      # Remove whitespace from variable:
      DATE=$(echo $DATE | sed -e 's/\d//')
      ;;
    i)
      INTERFACES=${OPTARG}
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      usage
      ;;
  esac
done

# Validate limits
if [ -n "${W_INC}" -a -n "${C_INC}" ] ; then
  if [ "${W_INC}" -ge "${C_INC}" ] ; then
    echo "The warning value of incoming traffic must be lower than the critical value of incoming traffic"
    exit ${UNKNOWN}
  fi
fi 

if [ -n "${W_OUT}" -a -n "${C_OUT}" ] ; then
  if [ "${W_OUT}" -ge "${C_OUT}" ] ; then
    echo "The warning value of outgoing traffic must be lower than the critical value of outgoing traffic"
    exit ${UNKNOWN}
  fi 
fi

get_interface_stats

