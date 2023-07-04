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
Simple PTF test for simple_l3_acl
"""


######### STANDARD MODULE IMPORTS ########
import logging 
import grpc   
import pdb

import struct

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
    def setUp(self):
        self.client_id = 0
        self.p4_name = "simple_l3_acl"
        self.dev      = 0
        self.dev_tgt  = gc.Target(self.dev, pipe_id=0xFFFF)
        
        print("\n")
        print("Test Setup")
        print("==========")

        BfRuntimeTest.setUp(self, self.client_id, self.p4_name)
        # This is the simple case when you run only one program on the target.
        # Otherwise, you might have to retrieve multiple bfrt_info objects and
        # in that case you will need to specify program name as a parameter
        self.bfrt_info = self.interface.bfrt_info_get()
        
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

        self.ipv4_acl = self.bfrt_info.table_get("Ingress.ipv4_acl")
        self.ipv4_acl.info.key_field_annotation_add(
            "hdr.ipv4.src_addr", "ipv4")
        self.ipv4_acl.info.key_field_annotation_add(
            "hdr.ipv4.dst_addr", "ipv4")
        
        self.tables = [ self.ipv4_host, self.ipv4_lpm, self.ipv4_acl]

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
        # Test parameters
        self.ingress_port  = test_param_get("ingress_port", 0)
        self.egress_port   = test_param_get("egress_port",  64)

        self.ipv4_dst      = test_param_get("ipv4_dst",      "192.168.1.1")
        self.ipv4_dst_mask = test_param_get("ipv4_dst_mask", "255.255.255.255")
        self.ipv4_src      = test_param_get("ipv4_src",      "10.11.12.13")
        self.ipv4_src_mask = test_param_get("ipv4_src_mask", "255.255.255.255")
        self.sport         = test_param_get("sport",         7)
        self.sport_mask    = test_param_get("sport_mask",    0xFFFF)
        self.dport         = test_param_get("dport",         0)
        self.dport_mask    = test_param_get("dport_mask",    0)
        self.frag          = test_param_get("frag",          1)
        self.frag_mask     = test_param_get("frag_mask",     1)
        
        # Program an entry in ipv4_lpm
        self.programTable(self.ipv4_lpm, [
            ([("hdr.ipv4.dst_addr", "0.0.0.0",     None, 0)],
             "Ingress.send", [("port", self.egress_port)])
        ])

        # Program an entry in ipv4_acl
        self.programTable(self.ipv4_acl, [
            ([("hdr.ipv4.src_addr",     self.ipv4_src, self.ipv4_src_mask),
              ("hdr.ipv4.dst_addr",     self.ipv4_dst, self.ipv4_dst_mask),
              ("hdr.ipv4.protocol",     0x11,          0xFF),    # UDP
              ("meta.l4_lookup.word_1", self.sport,    self.sport_mask),
              ("meta.l4_lookup.word_2", self.dport,    self.dport_mask),
              ("meta.first_frag",       self.frag,     self.frag_mask),
              ("$MATCH_PRIORITY",       1)],
             "Ingress.drop", [])
            ])
#
# The following are multiple tests that all use the same setup
#
# There are a lot of tests that can be run on this topology. Feel free to
# add more
#

class Test1_TCP__Pass(TestGroup1):
   def runTest(self):
        print("\n")
        print("Test Run:")
        print("=========")
        
        pkt = simple_tcp_packet(ip_dst    = self.ipv4_dst,
                                ip_src    = self.ipv4_src,
                                tcp_sport = self.sport,
                                tcp_dport = self.dport)
        
        print("Sending to Port {}\n{}".format(self.ingress_port, repr(pkt)))
        send_packet(self, self.ingress_port, pkt)
        print("Expecting the packet to be forwarded to port %d" %
              self.egress_port)
        verify_packet(self, pkt, self.egress_port)
        print("Packet received of port %d" % self.egress_port)

# Make IP options to look like the L4 header we are looking for.
# However, use a different protocol (TCP and not UDP).
# The packet should pass
class Test1_TCP_Options_Pass(TestGroup1):
   def runTest(self):
        print("\n")
        print("Test Run:")
        print("=========")
        
        pkt = simple_tcp_packet(ip_dst     = self.ipv4_dst,
                                ip_src     = self.ipv4_src,
                                tcp_sport  = self.sport,
                                tcp_dport  = self.dport,
                                ip_options = IPOption(struct.pack(
                                    "!HH", self.sport, self.dport)))
        
        print("Sending to Port {}\n{}".format(self.ingress_port, repr(pkt)))
        send_packet(self, self.ingress_port, pkt)
        print("Expecting the packet to be forwarded to port %d" %
              self.egress_port)
        verify_packet(self, pkt, self.egress_port)
        print("Packet received of port %d" % self.egress_port)

class Test1_UDP_Drop(TestGroup1):
    def runTest(self):
        print("\n")
        print("Test Run:")
        print("=========")
        
        pkt = simple_udp_packet(ip_dst    = self.ipv4_dst,
                                ip_src    = self.ipv4_src,
                                udp_sport = self.sport,
                                udp_dport = self.dport)
        
        print("Sending to Port {}\n{}".format(self.ingress_port, repr(pkt)))
        send_packet(self, self.ingress_port, pkt)
        print("Expecting the packet to be dropped")
        verify_no_packet_any(self, pkt, self.swports)
        print("No packets received on ports {}".format(self.swports))

class Test1_UDP_Options_Drop(TestGroup1):
    def runTest(self):
        print("\n")
        print("Test Run:")
        print("=========")
        
        pkt = simple_udp_packet(ip_dst     = self.ipv4_dst,
                                ip_src     = self.ipv4_src,
                                udp_sport  = self.sport,
                                udp_dport  = self.dport,
                                ip_options = IPOption("ABCDEFGH"))
        
        print("Sending to Port {}\n{}".format(self.ingress_port, repr(pkt)))
        send_packet(self, self.ingress_port, pkt)
        print("Expecting the packet to be dropped")
        verify_no_packet_any(self, pkt, self.swports)
        print("No packets received on ports {}".format(self.swports))

class Test1_TCP_BadIHL_Drop(TestGroup1):
    def runTest(self):
        print("\n")
        print("Test Run:")
        print("=========")
        
        pkt = simple_tcp_packet(ip_dst     = self.ipv4_dst,
                                ip_src     = self.ipv4_src,
                                tcp_sport  = self.sport,
                                tcp_dport  = self.dport,
                                ip_ihl     = 3,
                                ip_options = IPOption("ABCDEFGH"))
        
        print("Sending to Port {}\n{}".format(self.ingress_port, repr(pkt)))
        send_packet(self, self.ingress_port, pkt)
        print("Expecting the packet to be dropped")
        verify_no_packet_any(self, pkt, self.swports)
        print("No packets received on ports {}".format(self.swports))

#
# We send the same UDP packet that should normally be dropped, but
# it has non-zero fragment offset. It should not result in a false
# positive
#
class Test1_UDP_Fragment_Pass(TestGroup1):
    def runTest(self):
        frag_offset = test_param_get("frag_offset", 123)
        
        print("\n")
        print("Test Run:")
        print("=========")
        
        pkt = simple_udp_packet(ip_dst    = self.ipv4_dst,
                                ip_src    = self.ipv4_src,
                                udp_sport = self.sport,
                                udp_dport = self.dport)
        pkt[IP].frag = frag_offset
        
        print("Sending to Port {}\n{}".format(self.ingress_port, repr(pkt)))
        send_packet(self, self.ingress_port, pkt)
        print("Expecting the packet to be forwarded to port %d" %
              self.egress_port)
        verify_packet(self, pkt, self.egress_port)
        print("Packet received of port %d" % self.egress_port)
