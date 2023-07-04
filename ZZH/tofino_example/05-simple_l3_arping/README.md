simple_l3_arping
================

The goal of this exercise is to show how a typical L3 switch can also serve
as an automatic ARP and ICMP responder therefore relieving the hosts that
are located behind it from responding to these particular packets. This can
prevent some basic DOS attacks, but also allow to better hide the network on
the other side.

After completing the exercise (that is writing the program and programming
its tables accordingly) you should be able to configure an IP address on
one or more veth interfaces and ping the hosts that do not really exist
anywhere.

For example, you can program the following hosts and routes:

| IP address (prefix) | Port |  Destination MAC  |    Source MAC     |
|---------------------|-----:|:-----------------:|:-----------------:|
| 192.168.1.1         |    1 | 00:00:00:00:00:01 | 00:12:34:56:78:9A |
| 192.168.1.2         |    2 | 00:00:00:00:00:02 | 00:AA:BB:CC:DD:EE |
| 192.168.1.5         |    2 | 00:00:00:00:00:05 | 00:AA:BB:CC:DD:EE |
| 192.168.1.0/24      |   64 | 00:00:00:00:00:01 | 00:12:34:56:78:9A |
| 192.168.3.0/24      |   64 | 00:00:00:00:00:01 | 00:12:34:56:78:9A |

You can then configure IP address 192.168.1.254/24 on veth1 and also specify
that a host on 192.168.1.0/24 network (e.g 192.168.1.100) is a router for
another network, e.g. 192.168.3.0
```
sudo ip addr add 192.168.1.254/24 dev veth1
sudo ip route add 192.168.3.0/24 via 192.168.1.100
```
If program works correctly, you should be able to ping any host on
192.168.1.0/24 or 192.168.3.0/24 network even thought none of them exists in
reality.

The script `do_ping.sh` in this directory does exactly that (and unconfigures
veth1 at the end). You can use it as an example of how to test the program.

Theoretical Background
======================

When you ping an host with a given IP address the following events occur:
1. The routing table on your Linux machine is looked up. There are three
   possible outcomes:
   a. No route can be found. Then the ping fails
   b. The host is deemed to be on a directly attached network. This happens if
      you try to ping a host on the same subnet. In this case the IP stack
      will first perform ARP resolution by sending a "Who-has" ARP request
      for the host's IP address.
   c. The host is deemed to be on the remote network. In this case you IP stack
      will have to perform ARP resolution for the gateway. 

2. Once the MAC address of the destination (the host or the gateway) is known,
   your IP stack will send an ICMP Echo request directly to that destination,
   using its MAC address.

That's why the switch (responder) should be able to respond to both ARP and ICMP packets
      
Additional experiments
======================

