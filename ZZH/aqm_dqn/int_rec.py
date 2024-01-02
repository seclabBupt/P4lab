from scapy.all import *

class Tianchong(Packet):
    name = "queuevalue"
    fields_desc = [
        IntField("queue", 1),
        IntField("delay", 1),
        IntField("timecha", 1)
    ]

# 注册我们的自定义协议
bind_layers(IP, Tianchong, proto=251)

def process_packet(packet):
    if Tianchong in packet:
        queue_value = packet[Tianchong].queue
        delay_value = packet[Tianchong].delay
        timecha_value = packet[Tianchong].timecha

        print(f"Received packet - Queue: {queue_value}, Delay: {delay_value}, Timecha: {timecha_value}")

def main():
    sniff(iface="eth0", prn=process_packet, store=0, filter="proto 251")

if __name__ == '__main__':
    main()
