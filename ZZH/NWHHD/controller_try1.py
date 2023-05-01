import socket
import struct
import subprocess
from scapy.all import *
import threading

num_switch = 3
sampleList_size = 30
port = 9090
fraction = 0.2
sniff_port = ["cpu1","cpu2","cpu3"]
interval = 10

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
            + 'register_reset sampleList_count\n'
        for i in range(1, sampleList_size+1, 1):
            commands += "register_reset sketch%s\n" %str(i)
        p.communicate(input=commands.encode())

def resetAll():
    resetState(9090)
    resetState(9091)
    resetState(9092)

def globalHH():
    whole_network_volume = 0
    global_sampleList = {}
    hh_keys = []
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
        print (str(int2ip(src)) + " " + str(int2ip(dst)))

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

def listenport(num):
    i = 0
	while i < 10:
    	print("The sniffing port is set to: [{}]".format(sniff_port[num-1]))
    	sniff(iface=sniff_port[num-1], prn=getFlag, stop_filter=stopfilter, timeout=interval)
    	resetAll()
    	i += 1

t1=threading.Thread(target=listenport,args=(1,))
t2=threading.Thread(target=listenport,args=(2,))
t3=threading.Thread(target=listenport,args=(3,))

t1.start()
t2.start()
t3.start()

t1.join()
t2.join()
t3.join()
