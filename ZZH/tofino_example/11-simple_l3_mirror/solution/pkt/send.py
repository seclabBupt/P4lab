#!/usr/bin/python

import os
import sys

if os.getuid() !=0:
    print """
ERROR: This script requires root privileges. 
       Use 'sudo' to run it.
"""
    quit()

from scapy.all import *

try:
    ip_dst = sys.argv[1]
except:
    ip_dst = "192.168.1.2"

try:
    iface = sys.argv[2]
except:
    iface="veth1"

try:
    payload_len = int(sys.argv[3])
except:
    payload_len = 40
    
print "Sending IP packet to", ip_dst
p = (Ether(dst="00:11:22:33:44:55", src="00:aa:bb:cc:dd:ee")/
     IP(src="10.11.12.13", dst=ip_dst)/
     UDP(sport=7,dport=7)/
     "".join([chr((x % 63)+0x40) for x in range(0, payload_len)]))
sendp(p, iface=iface) 
