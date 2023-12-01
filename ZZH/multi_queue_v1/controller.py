import socket
import struct
import subprocess
from scapy.all import *

sampleList_size = 10
port = 9090
sniff_port = "s1-cpu-eth1"
interval = 100

def resetState(thrift_port):
    p = subprocess.Popen(['simple_switch_CLI', '--thrift-port', str(thrift_port)],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE)
    commands = 'register_reset packet_tot\n'+'register_reset queue_bound\n'+'register_reset past_count\n'
    for i in range(1, sampleList_size+1, 1):
        commands += "register_reset sketch%s\n" %str(i)
    p.communicate(input=commands.encode())

def resetAll():
    resetState(9090)

def getFlag(packet):
    rep = raw(packet)[0:1]
    return rep

def stopfilter(packet):
    if raw(packet)[0:1] == b'\x01':
        return True
    else:
        return False

i = 0
while i < 10000:
    print("The sniffing port is set to: [{}]".format(sniff_port))
    sniff(iface=sniff_port, prn=getFlag, stop_filter=stopfilter, timeout=interval)
    resetAll()
    i += 1
