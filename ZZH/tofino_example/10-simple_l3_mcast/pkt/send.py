#!/usr/bin/python

import os

if os.getuid() !=0:
    print """
ERROR: This script requires root privileges. 
       Use 'sudo' to run it.
"""
    quit()

from scapy.all import *
sendp(Ether()/IP(dst="224.0.0.1")/UDP()/"Payload", iface="veth1")
