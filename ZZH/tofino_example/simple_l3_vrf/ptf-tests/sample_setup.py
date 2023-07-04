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

from simple_l3_vrf import *


########################################################################
########    Running Multiple Tests with the same setup   ###############
########################################################################

# This new Base Class extends the setup method of BaseProgramTest by adding the
# desired network setup
class TestGroup1(BaseProgramTest):
    def setUp(self):
        BaseProgramTest.setUp(self)

        # 1. Assign VRF ID 5 to port 0
        
        # 2. Assign VRF ID 7 to port 1
        
        # 3. Add an entry for 192.168.1.1 (VRF 5) with the following parameters:
        #    a. Destination port 4
        #    b. New Destination MAC Address: 00:00:00:00:00:45
        #    c. New Source MAC address: 00:00:01:00:00:01

        # 4. Add an entry for 192.168.1.1 (VRF 7) with the following parameters:
        #    a. Destination port 5
        #    b.	New Destination MAC Address: 00:00:00:00:00:57
        #    c.	New Source MAC address: 00:00:02:00:00:02

#
# The following are multiple tests that all use the same setup
#
# There are a lot of tests that can be run on this topology. Feel free to
# add more
#

class VRF5_Pkt1(TestGroup1):
    """
    Sending a packet to 192.168.1.1 into port 0 (VRF 5) --> port 4
    """
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.1"
        ingress_port = 0
        egress_port  = 4
        
        send_pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                     eth_src='00:55:55:55:55:55',
                                     ip_dst=ipv4_dst,
                                     ip_id=101,
                                     ip_ttl=64,
                                     ip_options = IPOption("ABCD"))
        
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
        
class VRF7_Pkt1(TestGroup1):
    """
    Sending a packet to 192.168.1.1 into port 1 (VRF 7) --> port 5
    """
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.1"
        ingress_port = 1
        egress_port  = 5
        
        send_pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                     eth_src='00:55:55:55:55:55',
                                     ip_dst=ipv4_dst,
                                     ip_id=101,
                                     ip_ttl=64,
                                     ip_options = IPOption("ABCD"))
        
        exp_pkt = copy.deepcopy(send_pkt)
        exp_pkt[Ether].dst = "00:00:00:00:00:57"
        exp_pkt[Ether].src = "00:00:02:00:00:02"
        exp_pkt[IP].ttl   -= 1


        print("Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        send_packet(self, ingress_port, send_pkt)
        print("Expecting the modified packet to be forwarded to port %d" %
              egress_port)
        verify_packet(self, exp_pkt, egress_port)
        print("Modified packet received of port %d" % egress_port)

class BadChecksum(TestGroup1):
    """
    Verifying that packets with bad IPv4 checksum are dropped
    """
    def runTest(self):
        # Test Parameters
        ipv4_dst     = "192.168.1.1"
        ingress_port = 0
        
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_options = IPOption("ABCD"))
        # Corrupt the checksum
        send_pkt = Ether(str(pkt))
        send_pkt[IP].chksum += 1

        print("Sending packet with IPv4 DST ADDR=%s and bad checksum into port %d" %
              (ipv4_dst, ingress_port))
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
        ipv4_dst     = "192.168.1.1"
        ingress_port = 0
        
        print("Sending packet with IPv4 DST ADDR=%s and TTL=1 into port %d" %
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
