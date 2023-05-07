#!/usr/bin/env python3
import argparse
import sys
import socket
import random
import struct

from scapy.all import *
from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, IP, UDP, TCP

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
    name="clustervalue"
    fields_desc=[
        IntField("cpu",2),
        IntField("mem",3),
        IntField("disk",4),
        IntField("net",5)
    ]

def main():

    if len(sys.argv)<6:
        print('pass 2 arguments: <destination> <computing>')
        exit(1)

    addr = socket.gethostbyname(sys.argv[1])
    iface = get_if()

    print("sending on interface %s to %s" % (iface, str(addr)))
    pkt =  Ether(src=get_if_hwaddr(iface),dst = "00:00:00:00:04:41")
    pkt = pkt /IP(dst=addr, proto=251)
    pkt = pkt /tianchong(cpu=int(sys.argv[2]),mem=int(sys.argv[3]),disk=int(sys.argv[4]),net=int(sys.argv[5]))
    pkt.show2()
    sendp(pkt, iface=iface, verbose=False)


if __name__ == '__main__':
    main()
