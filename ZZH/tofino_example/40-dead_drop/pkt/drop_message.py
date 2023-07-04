#!/usr/bin/python

import os

if os.getuid() !=0:
    print """
ERROR: This script requires root privileges. 
       Use 'sudo' to run it.
"""
    quit()

from scapy.all import *

class DeadDrop(Packet):
    name = "Spy Dead-Drop"
    fields_desc = [ ShortField("box_num",   0),
                    ShortField("box_op",    0),
                    ShortField("data_dest", 511),
                    IntField("box_data",    0xDEADBABE)
                  ]

bind_layers(Ether, DeadDrop, type=0xDEAD)

sendp(Ether()/DeadDrop(box_num=5, box_op=0, data_dest=3, box_data=0x12345678), iface="veth1")
