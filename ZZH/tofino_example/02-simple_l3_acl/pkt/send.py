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

print "Sending IP packets with UDP Source Port 7 to", ip_dst

print "Packet 1: First Fragment, No Options"
p = (Ether(dst="00:11:22:33:44:55", src="00:aa:bb:cc:dd:ee")/
     IP(src="10.11.12.13", dst=ip_dst)/
     UDP(sport=7,dport=7)/
     "This is a test")
sendp(p, iface="veth1")

print "Packet 2: Second Fragment. No Options"
p[IP].frag=10
sendp(p, iface="veth1")

print "Packet 3: First Fragment, Options"
p[IP].frag=0
p[IP].options=IPOption("A"*8)
sendp(p, iface="veth1")


print "Packet 3: Second Fragment, Options"
p[IP].frag=10
sendp(p, iface="veth1")


