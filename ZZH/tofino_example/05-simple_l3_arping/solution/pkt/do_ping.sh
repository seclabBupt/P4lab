#!/bin/bash

usage() {
    cat <<EOF
Usage:
    sudo $0

    This program configures an IP address on veth1, 
    performs a series of pings and returns veth1 back to normal.

    This program is supposed to be run as root. 
EOF
}

PING_IF=veth1
MY_IP=192.168.1.254
MY_PREFIX_LEN=24

EXT_NET=192.168.3.0
EXT_NET_PREFIX_LEN=24
GATEWAY=192.168.1.1
PING_HOST=192.168.3.5

PING_COUNT=5

if [ $UID -ne 0 ]; then
    usage
    exit 1
fi

ip addr  add $MY_IP/$MY_PREFIX_LEN dev $PING_IF
ip route add $EXT_NET/$EXT_NET_PREFIX_LEN via $GATEWAY
ping -c $PING_COUNT $GATEWAY
ping -c $PING_COUNT $PING_HOST
arp -an
ip route del $EXT_NET/$EXT_NET_PREFIX_LEN via $GATEWAY
ip addr  del $MY_IP/$MY_PREFIX_LEN dev $PING_IF
