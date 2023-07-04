################################################################################
# BAREFOOT NETWORKS CONFIDENTIAL & PROPRIETARY
#
# Copyright (c) 2018-2019 Barefoot Networks, Inc.

# All Rights Reserved.
#
# NOTICE: All information contained herein is, and remains the property of
# Barefoot Networks, Inc. and its suppliers, if any. The intellectual and
# technical concepts contained herein are proprietary to Barefoot Networks,
# Inc.
# and its suppliers and may be covered by U.S. and Foreign Patents, patents in
# process, and are protected by trade secret or copyright law.
# Dissemination of this information or reproduction of this material is
# strictly forbidden unless prior written permission is obtained from
# Barefoot Networks, Inc.
#
# No warranty, explicit or implicit is provided, unless granted under a
# written agreement with Barefoot Networks, Inc.
#
#
###############################################################################

"""
Testing forwarding functionality across specific table setup
"""

# The simple_l3-REWRITE.py file in the same directory contains the
# foundational class, that is used for these individual tests

from simple_l3_rewrite import *


########################################################################
########    Running Multiple Tests with the same setup   ###############
########################################################################

# This new Base Class extends the setup method of Simple L3 by adding the
# desired network setup
class TestGroup1(BaseProgramTest):
    def setUp(self):
        BaseProgramTest.setUp(self)

        # Program 4 enrtries in ipv4_host
        self.programTable(self.ipv4_host, [
            ([("hdr.ipv4.dst_addr", "192.168.1.1")],
             "Ingress.send", [("port", 1)]),
            ([("hdr.ipv4.dst_addr", "192.168.1.2")],
             "Ingress.l3_switch",
             [("port", 2),
              ("new_mac_da", "00:00:00:00:00:45"),
              ("new_mac_sa", "00:00:01:00:00:01")]),
            ([("hdr.ipv4.dst_addr", "192.168.1.3")],
             "Ingress.drop", []),
            ([("hdr.ipv4.dst_addr", "192.168.1.254")],
             "Ingress.send", [("port", 64)]),
        ])

        # Program 3 entries in ipv4_lpm
        self.programTable(self.ipv4_lpm, [
            ([("hdr.ipv4.dst_addr", "192.168.1.0", None, 24)],
             "Ingress.send", [("port", 64)]),
            ([("hdr.ipv4.dst_addr", "192.168.0.0", None, 16)],
             "Ingress.drop", []),
            ([("hdr.ipv4.dst_addr", "0.0.0.0",     None, 0)],
             "Ingress.send", [("port", 64)])
        ])

#
# The following are multiple tests that all use the same setup
#
# There are a lot of tests that can be run on this topology. Feel free to
# add more
#

class Test1(TestGroup1):
    """
    Sending a packet to 192.168.1.1 (0-->1)
    """
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.1"
        ingress_port = 0
        egress_port  = 1

        print("Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        send_packet(self, ingress_port, pkt)
        print("Expecting the packet to be forwarded to port %d" % egress_port)
        verify_packet(self, pkt, egress_port)
        print("Packet received of port %d" % egress_port)
        
class Test2(TestGroup1):
    """
    Sending a packet to 192.168.1.2 (1->2 (with mods))
    """
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.2"
        ingress_port = 0
        egress_port  = 2
        
        send_pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        
        exp_pkt = copy.deepcopy(send_pkt)
        exp_pkt[Ether].dst = "00:00:00:00:00:45"
        exp_pkt[Ether].src = "00:00:01:00:00:01"
        exp_pkt[IP].ttl   -= 1


        print("Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        send_packet(self, ingress_port, send_pkt)
        print("Expecting the modified packet to be forwarded to port %d" %
              egress_port)
        verify_packet(self, exp_pkt, egress_port)
        print("Modified packet received of port %d" % egress_port)
        
class Test3(TestGroup1):
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.3"
        ingress_port = 0
                
        print("Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        send_packet(self, ingress_port, pkt)
        print("Expecting the packet to be dropped")
        verify_no_packet_any(self, pkt, self.swports)
        print("No packets received on ports {}".format(self.swports))
        
class Test4(TestGroup1):
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.250"
        ingress_port = 0
        egress_port  = 64
        
        print("Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        send_packet(self, ingress_port, pkt)
        print("Expecting the packet to be forwarded to port %d" % egress_port)
        verify_packet(self, pkt, egress_port)
        print("Packet received of port %d" % egress_port)

class IPv4Options(TestGroup1):
    """
    Verifying that packets with IPv4 Options are being handled correctly
    """
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.250"
        ingress_port = 0
        egress_port  = 64
        
        print("Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_options = IPOption("ABCD"))
        send_packet(self, ingress_port, pkt)
        print("Expecting the packet to be forwarded to port %d" % egress_port)
        verify_packet(self, pkt, egress_port)
        print("Packet received of port %d" % egress_port)

class BadChecksum(TestGroup1):
    """
    Verifying that packets with bad IPv4 checksum are dropped
    """
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.250"
        ingress_port = 0
        egress_port  = 64
        
        print("Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_options = IPOption("ABCD"))
        # Corrupt the checksum
        send_pkt = Ether(str(pkt))
        send_pkt[IP].chksum += 1
        send_packet(self, ingress_port, send_pkt)
        
        print("Expecting the packet to be dropped")
        verify_no_packet_any(self, pkt, self.swports)
        print("Packet dropped because of bad checksum")
        
class BadTTL(TestGroup1):
    """
    Verifying that packets with TTL=1 are dropped
    """
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.250"
        ingress_port = 0
        egress_port  = 64
        
        print("Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=1,
                                ip_options = IPOption("ABCD"))
        send_packet(self, ingress_port, pkt)
        print("Expecting the packet to be dropped")
        verify_no_packet_any(self, pkt, self.swports)
        print("Packet dropped because of TTL <= 1")
