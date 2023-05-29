import socket
import struct
import subprocess
from scapy.all import *

num_switch = 1
sampleList_size = 30
port = 9090
fraction = 0.2
sniff_port = "cpu1"
interval = 100

n=0
def del_table(thrift_port):
    p = subprocess.Popen(['simple_switch_CLI', '--thrift-port', str(thrift_port)],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE)
    commands = 'table_clear exist\n'
    commands += "table_clear heavy_drop\n"
    p.communicate(input=commands.encode())

def add_table(thrift_port):
    p = subprocess.Popen(['simple_switch_CLI', '--thrift-port', str(thrift_port)],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE)
    commands = 'table_add exist heavy_exist 2 =>\n'
    global n
    for i in range(n):
        commands += "table_add heavy_drop h_drop %s 2 => 15 4\n" %hh_keys_zu[i]
    p.communicate(input=commands.encode())

def readRegister(register, thrift_port):
    p = subprocess.Popen(['simple_switch_CLI', '--thrift-port', str(thrift_port)],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE)
    stdout, stderr = p.communicate(input=("register_read %s" % (register)).encode())
    reg = list(stdout.decode().strip().split("= ")[1].split("\n")[0].split(", "))
    reg = list(map(int, reg))
    return reg

def resetState(thrift_port):
    p = subprocess.Popen(['simple_switch_CLI', '--thrift-port', str(thrift_port)],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE)
    commands = 'register_reset hh_r\n'+'register_reset packet_tot\n'+\
        'register_reset sampleList_src\n'+'register_reset sampleList_dst\n'\
        + 'register_reset sampleList_count\n'+'register_reset port_packet\n'
    for i in range(1, sampleList_size+1, 1):
        commands += "register_reset sketch%s\n" %str(i)
    p.communicate(input=commands.encode())

def resetAll():
    resetState(9090)

def globalHH():
    whole_network_volume = 0
    for i in (range(num_switch)):
        locals()['src' + str(i+1)] = readRegister('sampleList_src', int(port+i))
        locals()['dst' + str(i+1)] = readRegister('sampleList_dst', int(port+i))
        locals()['count' + str(i+1)] = readRegister('sampleList_count', int(port+i))
    for i in (range(num_switch)):
        for j in (range(sampleList_size)):
            if locals()['src' + str(i+1)][j] != 0 and\
                    locals()['dst' + str(i+1)][j] != 0:
                flow_key = str(locals()['src' + str(i+1)][j] )+" "+str(locals()['dst' + str(i+1)][j] );
                if flow_key not in global_sampleList:
                    global_sampleList[flow_key] = int(locals()['count' + str(i+1)][j])
                elif global_sampleList[flow_key] > int(locals()['count' + str(i+1)][j]):
                     global_sampleList[flow_key] = int(locals()['count' + str(i+1)][j])
    print ('Global sample list:')
    print (global_sampleList)
    for value in global_sampleList.values():
        whole_network_volume += value
    global_threshold = whole_network_volume * fraction
    print ('Global threshold:')
    print (global_threshold)
    for key in global_sampleList.keys():
        if global_sampleList[key] > global_threshold:
            hh_keys.append(key)
    print ('Global heavy hitter keys:')
    for key in hh_keys:
        keylist = key.split()
        src = int(keylist[0])
        dst = int(keylist[1])
        key_str=str(int2ip(src)) + " " + str(int2ip(dst))
        hh_keys_zu.append(key_str)
        print (key_str)
    
    for i in (range(num_switch)):
        del_table(port+i)
    global n
    n=len(hh_keys)
    if n>0:
        for i in (range(num_switch)):
            add_table(port+i)
        
def int2ip(num):
    return socket.inet_ntoa(struct.pack("!I", num))


def getFlag(packet):
    rep = raw(packet)[0:1]
    return rep

def stopfilter(packet):
    if raw(packet)[0:1] == b'\x01':
        globalHH()
        return True
    else:
        return False

i = 0
while i < 10000:
    global_sampleList = {}
    hh_keys = []
    hh_keys_zu=[]
    print("The sniffing port is set to: [{}]".format(sniff_port))
    sniff(iface=sniff_port, prn=getFlag, stop_filter=stopfilter, timeout=interval)
    resetAll()
    i += 1
