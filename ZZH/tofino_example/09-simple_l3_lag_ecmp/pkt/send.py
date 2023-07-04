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
import random

try:
    ip_dst = sys.argv[1]
except:
    ip_dst = "192.168.1.2"

try:
    count = int(sys.argv[2])
except:
    count = 100
    
print "Sending %d IP packet(s) with random source addresses to %s" % (count, ip_dst)

for i in range(0, count):
    ip_src = "%d.%d.%d.%d" % (random.randint(1, 255), random.randint(0, 255),
                               random.randint(0, 255), random.randint(0, 255))

    p = (Ether(dst="00:11:22:33:44:55", src="00:aa:bb:cc:dd:ee")/
         IP(src=ip_src, dst=ip_dst)/
         UDP(sport=random.randint(0, 65535),dport=random.randint(0, 65535))/
         "This is a test")
    sendp(p, iface="veth1") 
