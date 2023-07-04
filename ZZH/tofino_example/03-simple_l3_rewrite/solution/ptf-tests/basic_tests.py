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
Basic functional PTF tests for simple_l3_rewrite
"""
# The simple_l3_rewrite.py file in the same directory contains the
# foundational class, that is used for these individual tests

from simple_l3_rewrite import *

############################################################################
################# I N D I V I D U A L    T E S T S #########################
############################################################################

class HostSend(BaseProgramTest):
    
    # The runTest() method represents the test itself. T
    #
    # Typically you would want to configure the device (e.g. by populating
    # the tables), send some traffic and check the results.
    #
    # For more flexible checks, you can import unittest module and use
    # the provided methods, such as unittest.assertEqual()
    #
    # Do not enclose the code into try/except/finally -- this is done by
    # the framework itself
    
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        egress_port  = test_param_get("egress_port",   4)

        print("\n")
        print("Test Run")
        print("========")

        #
        # Program an entry in IPv4: ipv4_dst --> send(egress_port)
        #
        key_list = [
            self.ipv4_host.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr', ipv4_dst)])
            ]

        data_list = [
            self.ipv4_host.make_data([
                gc.DataTuple('port', egress_port)], "Ingress.send")
            ]

        self.ipv4_host.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_host: {} --> send({})".format(
            ipv4_dst, egress_port))

        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        send_packet(self, ingress_port, pkt)

        #
        # Wait for the egress packet and verify it
        #
        print("  Expecting the packet to be forwarded to port %d" % egress_port)
        verify_packet(self, pkt, egress_port)
        print("  Packet received of port %d" % egress_port)

        ############# That's it! ###############

class HostL3Switch(BaseProgramTest):
    
    # The runTest() method represents the test itself. T
    #
    # Typically you would want to configure the device (e.g. by populating
    # the tables), send some traffic and check the results.
    #
    # For more flexible checks, you can import unittest module and use
    # the provided methods, such as unittest.assertEqual()
    #
    # Do not enclose the code into try/except/finally -- this is done by
    # the framework itself
    
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        new_mac_da   = test_param_get("new_mac_da",    "00:12:34:56:78:9A")
        new_mac_sa   = test_param_get("new_mac_sa",    "00:00:AA:BB:CC:DD")
        egress_port  = test_param_get("egress_port",   4)

        print("\n")
        print("Test Run")
        print("========")

        #
        # Program an entry in IPv4: ipv4_dst --> send(egress_port)
        #
        key_list = [
            self.ipv4_host.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr', ipv4_dst)])
        ]

        data_list = [
            self.ipv4_host.make_data([
                gc.DataTuple('port',       egress_port),
                gc.DataTuple('new_mac_da', new_mac_da),
                gc.DataTuple('new_mac_sa', new_mac_sa)],
                                     "Ingress.l3_switch")
        ]

        self.ipv4_host.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_host: {} --> l3_switch({}, {}, {})".format(
            ipv4_dst, egress_port, new_mac_da, new_mac_sa))

        #
        # Prepare the test packet and the expected packet
        send_pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                     eth_src='00:55:55:55:55:55',
                                     ip_dst=ipv4_dst,
                                     ip_id=101,
                                     ip_ttl=64,
                                     ip_ihl=5)
              
        exp_pkt = copy.deepcopy(send_pkt)
        exp_pkt[Ether].dst = new_mac_da
        exp_pkt[Ether].src = new_mac_sa
        exp_pkt[IP].ttl   -= 1

        # Finalize the checksums. If there is a mismatch due to checksums
        # we will clearly see the values that were expected
        exp_pkt = Ether(str(exp_pkt))
              
        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
              
        send_packet(self, ingress_port, send_pkt)

        #
        # Wait for the egress packet and verify it
        #
        print("  Expecting the modified packet to be forwarded to port %d" % egress_port)
        verify_packet(self, exp_pkt, egress_port)
        print("  Modified Packet received of port %d" % egress_port)

        ############# That's it! ###############

class HostDrop(BaseProgramTest):
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")

        print("\n")
        print("Test Run")
        print("========")
        
        #
        # Program an entry in IPv4: ipv4_dst --> drop()
        #
        key_list = [
            self.ipv4_host.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr', ipv4_dst)])
            ]

        data_list = [
            self.ipv4_host.make_data([], "Ingress.drop")
            ]

        self.ipv4_host.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_host: {} --> drop()".format(
            ipv4_dst))

        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        send_packet(self, ingress_port, pkt)
        print("  Expecting No packets anywhere")
        
        #
        # Wait to make sure no packet egresses anywhere. self.swports is the
        # list of all ports the test is using. It is set up in the setUp()
        # method of the parent class
        #
        verify_no_packet_any(self, pkt, self.swports)
        print("  No packets received")

class LpmSend(BaseProgramTest):
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        lpm_addr     = test_param_get("lpm_addr",      "192.168.1.0/24")
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        egress_port  = test_param_get("egress_port",   4)

        (lpm_ipv4, lpm_p_len) = lpm_addr.split("/")
        
        print("\n")
        print("Test Run")
        print("========")
        
        #
        # Program an entry in IPv4: lpm_addr/prefix --> send(egress_port)
        # Note the extra named argument (prefix_len) to gc.KeyTuple(). 
        #
        key_list = [
            self.ipv4_lpm.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr',
                            value=lpm_ipv4, prefix_len=int(lpm_p_len))])
            ]

        data_list = [
            self.ipv4_lpm.make_data([
                gc.DataTuple('port', egress_port)], "Ingress.send")
            ]

        print("\n")
        print("Test Run")
        print("========")
        self.ipv4_lpm.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_lpm: {}/{} --> send({})".format(
            lpm_ipv4, lpm_p_len, egress_port))

        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        send_packet(self, ingress_port, pkt)
        
        #
        # Wait for the egress packet and verify it. Since we do not expect
        # any modifications, we use the same pkt. 
        #
        print("  Expecting the packet to be forwarded to port %d" % egress_port)
        verify_packet(self, pkt, egress_port)
        print("  Packet received of port %d" % egress_port)

class LpmDrop(BaseProgramTest):
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        lpm_addr     = test_param_get("lpm_addr",      "192.168.1.0/24")
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        egress_port  = test_param_get("egress_port",   4)

        (lpm_ipv4, lpm_p_len) = lpm_addr.split("/")
        
        print("\n")
        print("Test Run")
        print("========")

        #
        # Program an entry in IPv4: lpm_addr/prefix --> drop()
        # Note the extra named argument (prefix_len) to gc.KeyTuple(). 
        #
        key_list = [
            self.ipv4_lpm.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr',
                            value=lpm_ipv4, prefix_len=int(lpm_p_len))])
            ]

        data_list = [
            self.ipv4_lpm.make_data([], "Ingress.drop")
            ]

        self.ipv4_lpm.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_lpm: {} --> drop()".format(
            lpm_addr))

        print("  Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        send_packet(self, ingress_port, pkt)
        print("  Expecting No packets anywhere")
        verify_no_packet_any(self, pkt, self.swports)
        print("  No packets received")

class LpmL3Switch(BaseProgramTest):
    
    # The runTest() method represents the test itself. T
    #
    # Typically you would want to configure the device (e.g. by populating
    # the tables), send some traffic and check the results.
    #
    # For more flexible checks, you can import unittest module and use
    # the provided methods, such as unittest.assertEqual()
    #
    # Do not enclose the code into try/except/finally -- this is done by
    # the framework itself
    
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        lpm_addr     = test_param_get("lpm_addr",      "192.168.1.0/24")
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        new_mac_da   = test_param_get("new_mac_da",    "00:12:34:56:78:9A")
        new_mac_sa   = test_param_get("new_mac_sa",    "00:00:AA:BB:CC:DD")
        egress_port  = test_param_get("egress_port",   4)

        (lpm_ipv4, lpm_p_len) = lpm_addr.split("/")
        
        print("\n")
        print("Test Run")
        print("========")

        #
        # Program an entry in IPv4: lpm_addr/prefix --> drop()
        # Note the extra named argument (prefix_len) to gc.KeyTuple(). 
        #
        key_list = [
            self.ipv4_lpm.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr',
                            value=lpm_ipv4, prefix_len=int(lpm_p_len))])
            ]

        data_list = [
            self.ipv4_lpm.make_data([
                gc.DataTuple('port',       egress_port),
                gc.DataTuple('new_mac_da', new_mac_da),
                gc.DataTuple('new_mac_sa', new_mac_sa)],
                                     "Ingress.l3_switch")
        ]

        self.ipv4_lpm.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_lpm: {} --> l3_switch({}, {}, {})".format(
            lpm_addr, egress_port, new_mac_da, new_mac_sa))

        #
        # Prepare the test packet and the expected packet
        send_pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                     eth_src='00:55:55:55:55:55',
                                     ip_dst=ipv4_dst,
                                     ip_id=101,
                                     ip_ttl=64,
                                     ip_ihl=5)
              
        exp_pkt = copy.deepcopy(send_pkt)
        exp_pkt[Ether].dst = new_mac_da
        exp_pkt[Ether].src = new_mac_sa
        exp_pkt[IP].ttl   -= 1

        # Finalize the checksums. If there is a mismatch due to checksums
        # we will clearly see the values that were expected
        exp_pkt = Ether(str(exp_pkt)) 
              
        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR=%s into port %d" %
              (ipv4_dst, ingress_port))
              
        send_packet(self, ingress_port, send_pkt)

        #
        # Wait for the egress packet and verify it
        #
        print("  Expecting the modified packet to be forwarded to port %d" % egress_port)
        verify_packet(self, exp_pkt, egress_port)
        print("  Modified Packet received of port %d" % egress_port)

        ############# That's it! ###############
