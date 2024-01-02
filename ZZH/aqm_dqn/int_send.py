#!/usr/bin/env python3
import argparse
import sys
import socket
import random
import struct
import time

from scapy.all import *
from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, IP, UDP, TCP

total_packets=200000
interval=1

def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    return iface

class tianchong(Packet):
    name="queuevalue"
    fields_desc=[
        IntField("queue",1),
        IntField("delay",1),
        IntField("timecha",1)
    ]

def main():
    for i in range(total_packets):
        iface = get_if()
        pkt =  Ether(src="00:00:00:00:01:03",dst = "00:00:00:00:01:12")
        pkt = pkt /IP(src="10.0.11.1",dst="10.0.6.1", proto=251)
        pkt = pkt /tianchong(queue=0,delay=0,timecha=0)
        sendp(pkt, iface=iface, verbose=False)
        print(f"Sent packet {i + 1}/{total_packets}")
        time.sleep(interval)


if __name__ == '__main__':
    main()
