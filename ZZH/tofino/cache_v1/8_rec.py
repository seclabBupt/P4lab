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
        if "ens7f0" in i:
            iface=i
            break
    if not iface:
        print("Cannot find ens7f0 interface")
        exit(1)
    return iface


def main():

    iface = get_if()

    print("sniffing")

    sniff(iface=iface, prn=lambda p: p.show())


if __name__ == '__main__':
    main()
