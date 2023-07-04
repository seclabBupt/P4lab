simple_l3_acl
=============

The purpose of this lab is to extend simple_l3 program with a simple
firewall. As a result you should become comfortable modifying and amending P4
programs and then going through the whole workflow process.

The major emphasis is on the correct parsing of IPv4 packets and especially 
Layer 4 headers even in the presence of options.

Your goal is to extend the parser accordingly as well as add a table that
can act as an ACL. The directory contains the starter program with all headers
predefined (to reduce the amount of typing).

Testing the program
===================

Install at least one host or route entry, e.g. to send packets with dstIP
192.168.1.1 to port 1 and install an ACL entry, e.g. to deny UDP
packets with sport=7.

Use a variety of packets to ensure that the ACL works correctly:

```
p1 = Ether()/IP(src="10.10.10.1", dst="192.168.1.1")/UDP(sport=7, dport=77)/"Payload"

p2 = Ether()/IP(src="10.10.10.1", dst="192.168.1.1", options=IPOption("abcdefgh"))/UDP(sport=7, dport=77)/"Payload"

# Think of whether this packet should pass or not
p3 = Ether()/IP(src="10.10.10.1", dst="192.168.1.1", frag=23)/UDP(sport=7, dport=77)/"Payload"

# How about this one?
p4 = Ether()/IP(src="10.10.10.1", dst="192.168.1.1", frag=23)/"\x00\x07\x00\xc5    Payload"
```

**Note**: pkt/send.py still sends a simple packet, similar to `p1`. Given the
variety of packets needed for testing it is probably easier to use scapy
directly

Install another entry for a protocol that is not being explicitly parsed (e.g. SCTP (ipv4.protocol=132)) and make sure everything works.

```
p4 = Ether()/IP(src="10.10.10.1", dst="192.168.1.1")/SCTP(sport=7, dport=77)/"Payload"
```

Add additional, more specific entries to the ACL. For example:
* Allow UDP packets with sport=7 and dport=7
* Deny UDP packets with sport=7 and any other dport value

How would you do that? Check that more specific rules do win.

Additional exercises
======================

1. Add the code for the egress ACL
2. Add code to handle IPv4 fragmented packets correctly
3. Add IPv6 support
