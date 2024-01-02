import socket
import struct
import subprocess
import argparse
import sys

from scapy.all import *

def add_table(thrift_port, param1, param2):
    command = f"table_modify aqm go_to_drop 0 {param1} {param2}\n"

    p = subprocess.Popen(['simple_switch_CLI', '--thrift-port', str(thrift_port)],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE)

    p.communicate(input=command.encode())

def main():
    # 固定 thrift_port 为 9090
    thrift_port = 9090
    
    if len(sys.argv) != 3:
        print("Usage: python your_script.py <param1> <param2>")
        sys.exit(1)

    param1 = int(float(sys.argv[1]))
    param2 = int(float(sys.argv[2]))
    add_table(thrift_port, param1, param2)
    print(4)

if __name__ == "__main__":
    main()
