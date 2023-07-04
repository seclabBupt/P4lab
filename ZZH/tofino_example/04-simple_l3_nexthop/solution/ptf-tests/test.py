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
Simple PTF test for simple_l3_nexthop
"""

######### STANDARD MODULE IMPORTS ########
import logging 
import grpc   
import pdb

######### PTF modules for BFRuntime Client Library APIs #######
import ptf
from ptf.testutils import *
from bfruntime_client_base_tests import BfRuntimeTest
import bfrt_grpc.bfruntime_pb2 as bfruntime_pb2
import bfrt_grpc.client as gc

########## Basic Initialization ############
class BaseProgramTest(BfRuntimeTest):
    # The setUp() method is used to prepare the test fixture. Typically
    # you would use it to establich connection to the gRPC Server
    #
    # You can also put the initial device configuration there. However,
    # if during this process an error is encountered, it will be considered
    # as a test error (meaning the test is incorrect),
    # rather than a test failure
    #
    # Here is the stuff we set up that is ready to use
    #  client_id
    #  p4_name
    #  bfrt_info
    #  dev
    #  dev_tgt
    #  allports
    #  tables    -- the list of tables
    #     Individual tables of the program with short names
    #     ipv4_host
    #     ipv4_lpm
    #     nexthop
    def setUp(self):
        self.client_id = 0
        self.p4_name = "simple_l3_nexthop"
        self.dev      = 0
        self.dev_tgt  = gc.Target(self.dev, pipe_id=0xFFFF)
        
        print("\n")
        print("Test Setup")
        print("==========")

        BfRuntimeTest.setUp(self, self.client_id, self.p4_name)
        self.bfrt_info = self.interface.bfrt_info_get(self.p4_name)

        print("    Connected to Device: {}, Program: {}, ClientId: {}".format(
            self.dev, self.p4_name, self.client_id))

        # Since this class is not a test per se, we can use the setup method
        # for common setup. For example, we can have our tables and annotations
        # ready
        self.ipv4_host = self.bfrt_info.table_get("Ingress.ipv4_host")
        self.ipv4_host.info.key_field_annotation_add(
            "hdr.ipv4.dst_addr", "ipv4")

        self.ipv4_lpm = self.bfrt_info.table_get("Ingress.ipv4_lpm")
        self.ipv4_lpm.info.key_field_annotation_add(
            "hdr.ipv4.dst_addr", "ipv4")

        self.nexthop = self.bfrt_info.table_get("Ingress.nexthop")
        self.nexthop.info.data_field_annotation_add(
            "new_mac_da", "Ingress.l3_switch", "mac")
        self.nexthop.info.data_field_annotation_add(
            "new_mac_sa", "Ingress.l3_switch", "mac")

        self.tables = [ self.ipv4_host, self.ipv4_lpm, self.nexthop ]

        # Create a list of all ports available on the device
        self.swports = []
        for (device, port, ifname) in ptf.config['interfaces']:
            self.swports.append(port)
        self.swports.sort()

        # Optional, but highly recommended
        self.cleanUp()

    # Use Cleanup Method to clear the tables before and after the test starts
    # (the latter is done as a part of tearDown()
    def cleanUp(self):
        print("\n")
        print("Table Cleanup:")
        print("==============")

        try:
            for t in self.tables:
                print("  Clearing Table {}".format(t.info.name_get()))
                keys = []
                for (d, k) in t.entry_get(self.dev_tgt):
                    if k is not None:
                        keys.append(k)
                t.entry_del(self.dev_tgt, keys)
                # Not all tables support default entry
                try:
                    t.default_entry_reset(self.dev_tgt)
                except:
                    pass
        except Exception as e:
            print("Error cleaning up: {}".format(e))

    # Use tearDown() method to return the DUT to the initial state by cleaning
    # all the configuration and clearing up the connection
    def tearDown(self):
        print("\n")
        print("Test TearDown:")
        print("==============")

        self.cleanUp()
        
        # Call the Parent tearDown
        BfRuntimeTest.tearDown(self)

#
# Individual tests can now be subclassed from BaseProgramTest
#

############################################################################
################# I N D I V I D U A L    T E S T S #########################
############################################################################

class HostSend(BaseProgramTest):
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        egress_port  = test_param_get("egress_port",   4)
        nexthop_id   = test_param_get("nexthop_id",  100)
        
        print("\n")
        print("Test Run")
        print("========")

        #
        # Program an entry in nexthop: nexthop_id --> send(egress_port)
        #
        key = self.nexthop.make_key([
            gc.KeyTuple('nexthop_id', nexthop_id)])

        data = self.nexthop.make_data([
            gc.DataTuple('port', egress_port)], "Ingress.send")

        self.nexthop.entry_add(self.dev_tgt, [key], [data]);
        print("  Added an entry to nexthop: {} --> send({})".format(
            nexthop_id, egress_port))

        #
        # Program an entry in ipv4_host: ipv4_dst --> set_nexthop(nexthop_id)
        #
        key = self.ipv4_host.make_key([
            gc.KeyTuple('hdr.ipv4.dst_addr', ipv4_dst)])

        data = self.ipv4_host.make_data([
            gc.DataTuple('nexthop', nexthop_id)], "Ingress.set_nexthop")

        self.ipv4_host.entry_add(self.dev_tgt, [key], [data])
        print("  Added an entry to ipv4_host: {} --> set_nexthop({})".
              format(ipv4_dst, nexthop_id))

        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR={} into port {}"
              .format(ipv4_dst, ingress_port))
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
        print("  Expecting the packet to be forwarded to port {}"
              .format(egress_port))
        verify_packet(self, pkt, egress_port)
        print("  Packet received of port {}".format(egress_port))


class HostDrop(BaseProgramTest):
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        nexthop_id   = test_param_get("nexthop_id",  100)

        print("\n")
        print("Test Run")
        print("========")
        
        #
        # Program an entry in nexthop: nexthop_id --> drop()
        #
        key_list = [
            self.nexthop.make_key([
                gc.KeyTuple('nexthop_id', nexthop_id)])
            ]

        data_list = [
            self.nexthop.make_data([], "Ingress.drop")
            ]

        self.nexthop.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to nexthop: {} --> drop()".
              format(nexthop_id))

        #
        # Program an entry in ipv4_host: ipv4_dst --> set_nexthop(nexthop_id)
        #
        key_list = [
            self.ipv4_host.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr', ipv4_dst)])
            ]

        data_list = [
            self.ipv4_host.make_data([
                gc.DataTuple('nexthop', nexthop_id)], "Ingress.set_nexthop")
            ]

        self.ipv4_host.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_host: {} --> drop()".format(
            ipv4_dst))

        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR={} into port {}"
              .format(ipv4_dst, ingress_port))
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

class HostL3Switch(BaseProgramTest):
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        new_mac_da   = test_param_get("new_mac_da",    "00:12:34:56:78:9A")
        new_mac_sa   = test_param_get("new_mac_sa",    "00:00:AA:BB:CC:DD")
        egress_port  = test_param_get("egress_port",   4)
        nexthop_id   = test_param_get("nexthop_id",  100)

        print("\n")
        print("Test Run")
        print("========")

        #
        # Program an entry in nexthop:
        #       nexthop_id --> l3_switch(egress_port. new_mac_da, new_mac_da)
        #
        key = self.nexthop.make_key([
                gc.KeyTuple('nexthop_id', nexthop_id)])

        data = self.nexthop.make_data([
            gc.DataTuple('port', egress_port),
            gc.DataTuple('new_mac_da', new_mac_da),
            gc.DataTuple('new_mac_sa', new_mac_sa)],
            "Ingress.l3_switch")

        self.nexthop.entry_add(self.dev_tgt, [key], [data]);
        print("  Added an entry to nexthop: {} --> l3_switch({}, {}, {})".
              format(nexthop_id, egress_port, new_mac_da, new_mac_sa))

        #
        # Program an entry in IPv4: ipv4_dst --> set_nexthop(nexthop_id)
        #
        key = self.ipv4_host.make_key([
            gc.KeyTuple('hdr.ipv4.dst_addr', ipv4_dst)])

        data = self.ipv4_host.make_data([
                gc.DataTuple('nexthop', nexthop_id)],
                "Ingress.set_nexthop")

        self.ipv4_host.entry_add(self.dev_tgt, [key], [data]);
        print("  Added an entry to ipv4_host: {} --> set_nexthop({})".
              format(ipv4_dst, nexthop_id))

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
              
        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR={} into port {}"
              .format(ipv4_dst, ingress_port))
              
        send_packet(self, ingress_port, send_pkt)

        #
        # Wait for the egress packet and verify it
        #
        print("  Expecting the modified packet to be forwarded to port {}"
              .format(egress_port))
        
        verify_packet(self, exp_pkt, egress_port)
        print("  Modified Packet received of port {}"
              .format(egress_port))

class LpmSend(BaseProgramTest):
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        lpm_addr     = test_param_get("lpm_addr",      "192.168.1.0/24")
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        egress_port  = test_param_get("egress_port",   4)
        nexthop_id   = test_param_get("nexthop_id",  100)

        (lpm_ipv4, lpm_p_len) = lpm_addr.split("/")
        
        print("\n")
        print("Test Run")
        print("========")
        
        #
        # Program an entry in nexthop: nexthop_id --> send(egress_port)
        #
        key_list = [
            self.nexthop.make_key([
                gc.KeyTuple('nexthop_id', nexthop_id)])
            ]

        data_list = [
            self.nexthop.make_data([
                gc.DataTuple('port', egress_port)], "Ingress.send")
            ]

        self.nexthop.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to nexthop: {} --> send({})".format(
            nexthop_id, egress_port))

        #
        # Program an entry in ipv4_lpm:
        #          lpm_addr/prefix --> set_nexthop(nexthop_id)
        # Note the extra named argument (prefix_len) to gc.KeyTuple(). 
        #
        key_list = [
            self.ipv4_lpm.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr',
                            value=lpm_ipv4, prefix_len=int(lpm_p_len))])
            ]

        data_list = [
            self.ipv4_lpm.make_data([
                gc.DataTuple('nexthop', nexthop_id)], "Ingress.set_nexthop")
            ]

        self.ipv4_lpm.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_lpm: {}/{} --> set_nexthop({})".format(
            lpm_ipv4, lpm_p_len, nexthop_id))

        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR={} into port {}".
              format(ipv4_dst, ingress_port))
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
        print("  Expecting the packet to be forwarded to port {}".
              format(egress_port))
        
        verify_packet(self, pkt, egress_port)
        print("  Packet received on port {}".format(egress_port))

class LpmDrop(BaseProgramTest):
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        lpm_addr     = test_param_get("lpm_addr",      "192.168.1.0/24")
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        nexthop_id   = test_param_get("nexthop_id",  100)

        (lpm_ipv4, lpm_p_len) = lpm_addr.split("/")
        
        print("\n")
        print("Test Run")
        print("========")

        #
        # Program an entry in nexthop: nexthop_id --> drop()
        #
        key_list = [
            self.nexthop.make_key([
                gc.KeyTuple('nexthop_id', nexthop_id)])
            ]

        data_list = [
            self.nexthop.make_data([], "Ingress.drop")
            ]

        self.nexthop.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to nexthop: {} --> drop()".
              format(nexthop_id))

        #
        # Program an entry in ipv4_lpm:
        #          lpm_addr/prefix --> set_nexthop(nexthop_id)
        # Note the extra named argument (prefix_len) to gc.KeyTuple(). 
        #
        key_list = [
            self.ipv4_lpm.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr',
                            value=lpm_ipv4, prefix_len=int(lpm_p_len))])
            ]

        data_list = [
            self.ipv4_lpm.make_data([
                gc.DataTuple('nexthop', nexthop_id)], "Ingress.set_nexthop")
            ]

        self.ipv4_lpm.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_lpm: {}/{} --> set_nexthop({})".format(
            lpm_ipv4, lpm_p_len, nexthop_id))

        #
        # Send the Test Packet
        #
        print("  Sending packet with IPv4 DST ADDR{} into port {}".
              format(ipv4_dst, ingress_port))
        
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
    def runTest(self):
        ingress_port = test_param_get("ingress_port",  0)
        lpm_addr     = test_param_get("lpm_addr",      "192.168.1.0/24")
        ipv4_dst     = test_param_get("ipv4_dst",      "192.168.1.1")
        new_mac_da   = test_param_get("new_mac_da",    "00:12:34:56:78:9A")
        new_mac_sa   = test_param_get("new_mac_sa",    "00:00:AA:BB:CC:DD")
        egress_port  = test_param_get("egress_port",   4)
        nexthop_id   = test_param_get("nexthop_id",  100)

        (lpm_ipv4, lpm_p_len) = lpm_addr.split("/")
        
        print("\n")
        print("Test Run")
        print("========")

        #
        # Program an entry in nexthop:
        #       nexthop_id --> l3_switch(egress_port. new_mac_da, new_mac_da)
        #
        key_list = [
            self.nexthop.make_key([
                gc.KeyTuple('nexthop_id', nexthop_id)])
            ]

        data_list = [
            self.nexthop.make_data([gc.DataTuple('port', egress_port),
                                    gc.DataTuple('new_mac_da', new_mac_da),
                                    gc.DataTuple('new_mac_sa', new_mac_sa)],
                                   "Ingress.l3_switch")
            ]

        self.nexthop.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to nexthop: {} --> send({})".
              format(nexthop_id, egress_port))

        #
        # Program an entry in ipv4_lpm:
        #          lpm_addr/prefix --> set_nexthop(nexthop_id)
        # Note the extra named argument (prefix_len) to gc.KeyTuple(). 
        #
        key_list = [
            self.ipv4_lpm.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr',
                            value=lpm_ipv4, prefix_len=int(lpm_p_len))])
            ]

        data_list = [
            self.ipv4_lpm.make_data([
                gc.DataTuple('nexthop', nexthop_id)], "Ingress.set_nexthop")
            ]

        self.ipv4_lpm.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_lpm: {}/{} --> set_nexthop({})".format(
            lpm_ipv4, lpm_p_len, nexthop_id))
        #
        # Prepare the test packet and the expected packet
        #
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
              
        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR={} into port {}".
              format(ipv4_dst, ingress_port))
              
        send_packet(self, ingress_port, send_pkt)

        #
        # Wait for the egress packet and verify it
        #
        print("  Expecting the modified packet to be forwarded to port {}".
              format(egress_port))
        verify_packet(self, exp_pkt, egress_port)
        print("  Modified Packet received of port {}".format(egress_port))

########################################################################
########    Running Multiple Tests with the same setup   ###############
########################################################################

# This new Base Class extends the setup method of Simple L3 by adding the
# desired network setup
class TestGroup1(BaseProgramTest):

    #
    # This is a simple function that takes a list of entries and programs
    # them in a specified table
    #
    # Each entry is a tuple, consisting of 3 elements:
    #  key         -- a list of tuples for each element of the key
    #  action_name -- the action to use. Must use full name of the action
    #  data        -- a list (may be empty) of the tuples for each action
    #                 parameter
    #
    def programTable(self, table, entries, target=None):
        if target is None:
            target = self.dev_tgt

        key_list=[]
        data_list=[]
        for k, a, d in entries:
            key_list.append(table.make_key([gc.KeyTuple(*f)   for f in k]))
            data_list.append(table.make_data([gc.DataTuple(*p) for p in d], a))
        table.entry_add(target, key_list, data_list)
        
    def setUp(self):
        BaseProgramTest.setUp(self)

        print("\n")
        print("Table Setup")
        print("===========")
        
        # Nexthop programming
        print("    nexthop")
        self.programTable(self.nexthop, [
            ([("nexthop_id",   0)], "Ingress.send", [("port", 64)]),
            ([("nexthop_id",   1)], "Ingress.drop", []),
            ([("nexthop_id", 101)], "Ingress.l3_switch", [
                ("port", 1),
                ("new_mac_da", "00:00:01:00:00:01"),
                ("new_mac_sa", "00:00:FF:00:00:FE")]),
            ([("nexthop_id", 102)], "Ingress.l3_switch", [
                ("port", 2),
                ("new_mac_da", "00:00:02:00:00:01"),
                ("new_mac_sa", "00:00:FF:00:00:FE")]),
            ([("nexthop_id", 103)], "Ingress.l3_switch", [
                ("port", 4),
                ("new_mac_da", "FF:FF:FF:FF:FF:FF"),
                ("new_mac_sa", "00:12:34:56:78:9A")])
        ])
        
        # ipv4_host programming
        print("    ipv4_host")
        self.programTable(self.ipv4_host, [
            ([("hdr.ipv4.dst_addr", "192.168.1.1")],
             "Ingress.set_nexthop", [("nexthop", 101)]),
            ([("hdr.ipv4.dst_addr", "192.168.1.2")],
             "Ingress.set_nexthop", [("nexthop", 102)]),
            ([("hdr.ipv4.dst_addr", "192.168.1.3")],
             "Ingress.set_nexthop", [("nexthop", 1)]),
            ([("hdr.ipv4.dst_addr", "192.168.1.254")],
             "Ingress.set_nexthop", [("nexthop", 0)]),
        ])

        # ipv4_lpm programming
        print("    ipv4_lpm")
        self.programTable(self.ipv4_lpm, [
            ([("hdr.ipv4.dst_addr", "192.168.1.0", None, 24)],
             "Ingress.set_nexthop", [("nexthop",    0)]),
            ([("hdr.ipv4.dst_addr", "192.168.3.0", None, 24)],
              "Ingress.set_nexthop", [("nexthop", 101)]),
            ([("hdr.ipv4.dst_addr", "192.168.5.0", None, 24)],
              "Ingress.set_nexthop", [("nexthop", 101)]),
            ([("hdr.ipv4.dst_addr", "192.168.7.0", None, 24)],
              "Ingress.set_nexthop", [("nexthop", 101)]),
           ([("hdr.ipv4.dst_addr", "192.168.0.0",  None, 16)],
              "Ingress.set_nexthop", [("nexthop",   1)]),
          ([("hdr.ipv4.dst_addr", "0.0.0.0",       None,  0)],
              "Ingress.set_nexthop", [("nexthop",   0)]),
        ])

#
# The following are multiple tests that all use the same setup
#
# There are a lot of tests that can be run on this topology. Feel free to
# add more
#

class BadTTL(TestGroup1):
    def runTest(self):
        ingress_port = test_param_get("ingress_port", 0)
        ipv4_dst     = test_param_get("ipv4_dst",     "192.168.1.1") 
        ttl          = test_param_get("ttl",          1)
        
        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR={} into port {}"
              .format(ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=ttl,
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

class BadChecksum(TestGroup1):
    def runTest(self):
        ingress_port = test_param_get("ingress_port", 0)
        ipv4_dst     = test_param_get("ipv4_dst",     "192.168.1.1") 
        chksum       = test_param_get("chksum",       123)
        
        #
        # Send a test packet
        #
        print("  Sending packet with IPv4 DST ADDR={} into port {}"
              .format(ipv4_dst, ingress_port))
        pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_dst,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        # Corrupt checksum
        pkt[IP].chksum = chksum
        
        send_packet(self, ingress_port, pkt)
        print("  Expecting No packets anywhere")
        
        #
        # Wait to make sure no packet egresses anywhere. self.swports is the
        # list of all ports the test is using. It is set up in the setUp()
        # method of the parent class
        #
        verify_no_packet_any(self, pkt, self.swports)
        print("  No packets received")
