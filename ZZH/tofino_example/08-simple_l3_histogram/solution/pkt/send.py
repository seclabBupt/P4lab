#!/usr/bin/python

from scapy.all import *
import random

p = Ether()/IP()/UDP()/"Payload"

hist=[0, 0, 0, 0, 0, 0, 0]

for i in range(0, 1000):
    payload_len = random.randint(0, 3000)
    p[Raw].load="".join([chr((x % 63)+0x40) for x in range(0, payload_len)])
    
    if len(p)+4 >= 1523:
        hist[6] = hist[6] + 1
    elif len(p)+4 >= 1023:
        hist[5] = hist[5] + 1
    elif len(p)+4 >= 512:
        hist[4] = hist[4] + 1
    elif len(p)+4 >= 256:
        hist[3] = hist[3] + 1
    elif len(p)+4 >= 128:
        hist[2] = hist[2] + 1
    elif len(p)+4 >= 64:
        hist[1] = hist[1] + 1
    else:
        hist[0] = hist[0] + 1
        
    sendp(p, iface="veth%d" % (random.randint(0, 8)*2+1), verbose=0)
    
print hist
