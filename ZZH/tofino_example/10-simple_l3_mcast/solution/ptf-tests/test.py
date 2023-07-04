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
Simple PTF test for simple_l3_mcast (and simple_l3_mcast_checksum)
"""


######### STANDARD MODULE IMPORTS ########
import logging 
import grpc   
import pdb

######### PTF modules for BFRuntime Client Library APIs #######
import ptf
from ptf.testutils import *
from ptf.dataplane import *

from bfruntime_client_base_tests import BfRuntimeTest
import bfrt_grpc.bfruntime_pb2 as bfruntime_pb2
import bfrt_grpc.client as gc

######## PTF modules for Fixed APIs (Thrift) ######
import pd_base_tests
from ptf.thriftutils   import *
from res_pd_rpc.ttypes import *       # Common data types
from mc_pd_rpc.ttypes  import *       # Multicast-specific data types

########## Basic Initialization ############
class BaseProgramTest(BfRuntimeTest):
    
    #
    # This is a special class that will provide us with the interface to
    # the fixed APIs via the corresponding Thrift bindings. This particular
    # class provides access to all fixed APIs, but the cleanup routine is
    # implemented for multicast objects only
    #
    class FixedAPIs(pd_base_tests.ThriftInterfaceDataPlane):
        def __init__(self, p4names):
            pd_base_tests.ThriftInterfaceDataPlane.__init__(self, p4names)
            
        def setUp(self):
            pd_base_tests.ThriftInterfaceDataPlane.setUp(self)
            self.dev = 0
            self.mc_sess  = self.mc.mc_create_session()
            print("Opened MC Session {:#08x}".format(self.mc_sess))
            
        def cleanUp(self):
            try:
                print("  Deleting Multicast Groups")
                mgrp_count = self.mc.mc_mgrp_get_count(self.mc_sess, self.dev)
                if mgrp_count > 0:
                    mgrp_list  = [self.mc.mc_mgrp_get_first(self.mc_sess, self.dev)]
                    if mgrp_count > 1:
                        mgrp_list.extend(self.mc.mc_mgrp_get_next_i(
                            self.mc_sess, self.dev,
                            mgrp_list[-1], mgrp_count - 1))
                    
                    for mgrp in mgrp_list:
                        self.mc.mc_mgrp_destroy(self.mc_sess, self.dev, mgrp)
                    
                print("  Deleting Multicast ECMP Entries")
                ecmp_count = self.mc.mc_ecmp_get_count(self.mc_sess, self.dev)
                if ecmp_count > 0:
                    ecmp_list  = [self.mc.mc_ecmp_get_first(self.mc_sess, self.dev)]
                    if ecmp_count > 1:
                        ecmp_list.extend(self.mc.mc_ecmp_get_next_i(
                            self.mc_sess, self.dev,
                            ecmp_list[-1], ecmp_count - 1))
                    
                    for ecmp in ecmp_list:
                        self.mc.mc_ecmp_destroy(self.mc_sess, self.dev, ecmp)

                print("  Deleting Multicast Nodes")
                node_count = self.mc.mc_node_get_count(self.mc_sess, self.dev)
                if node_count > 0:
                    node_list  = [self.mc.mc_node_get_first(self.mc_sess, self.dev)]
                    if node_count > 1:
                        node_list.extend(self.mc.mc_node_get_next_i(
                            self.mc_sess, self.dev,
                            node_list[-1], node_count - 1))
                    
                    for node in node_list:
                        self.mc.mc_node_destroy(self.mc_sess, self.dev, node)
                    
                print("  Clearing Multicast LAGs")
                for lag in range(0, 255):
                    self.mc.mc_set_lag_membership(
                        self.mc_sess, self.dev,
                        hex_to_byte(lag), devports_to_mcbitmap([]))

                print("  Clearing Port Pruning Table")
                for yid in range(0, 288):
                    self.mc.mc_update_port_prune_table(
                        self.mc_sess, self.dev,
                        hex_to_i16(yid), devports_to_mcbitmap([]));

            except:
                print("  Error while cleaning up multicast objects. ")
                print("  You might need to restart the driver")
            finally:
                self.mc.mc_complete_operations(self.mc_sess)

        def runTest(self):
            pass
        
        def tearDown(self):
            self.mc.mc_destroy_session(self.mc_sess)
            print("  Closed MC Session %#08x" % self.mc_sess)
            pd_base_tests.ThriftInterfaceDataPlane.tearDown(self)
            
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
        self.checksum = test_param_get("checksum", False)
        self.client_id = 0
        self.dev      = 0
        self.dev_tgt  = gc.Target(self.dev, pipe_id=0xFFFF)

        if self.checksum:
            self.p4_name = "simple_l3_mcast_checksum"
        else:
            self.p4_name = "simple_l3_mcast"
            
        print("\n")
        print("Test Setup")
        print("==========")

        BfRuntimeTest.setUp(self, self.client_id, self.p4_name)
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

        self.mcast_mods = self.bfrt_info.table_get("Egress.mcast_mods")
        self.mcast_mods.info.data_field_annotation_add(
            "dstmac", "Egress.modify_packet_vlan", "mac")
        self.mcast_mods.info.data_field_annotation_add(
            "dstmac", "Egress.modify_packet_no_vlan", "mac")
        self.mcast_mods.info.data_field_annotation_add(
            "dstip", "Egress.modify_packet_vlan", "ipv4")
        self.mcast_mods.info.data_field_annotation_add(
            "dstip", "Egress.modify_packet_no_vlan", "ipv4")

        self.tables = [ self.ipv4_host, self.ipv4_lpm, self.mcast_mods]

        # Create a list of all ports available on the device
        self.swports = []
        for (device, port, ifname) in ptf.config['interfaces']:
            self.swports.append(port)
        self.swports.sort()

        ###### FIXED API SETUP #########
        self.fixed = self.FixedAPIs([self.p4_name])
        self.fixed.setUp()
        
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

        # CleanUp Fixed API objects
        self.fixed.cleanUp()

    # Use tearDown() method to return the DUT to the initial state by cleaning
    # all the configuration and clearing up the connection
    def tearDown(self):
        print("\n")
        print("Test TearDown:")
        print("==============")

        self.cleanUp()
        
        # Call the Parent tearDown
        BfRuntimeTest.tearDown(self)
        self.fixed.tearDown()

#
# Helper functions for Tofino. We could've put them into a separate file, but
# that would complicate shipping. If their number grows, we'll do something
#
def to_devport(pipe, port):
    """
    Convert a (pipe, port) combination into a 9-bit (devport) number
    NOTE: For now this is a Tofino-specific method
    """
    return pipe << 7 | port

def to_pipeport(dp):
    """
    Convert a physical 9-bit (devport) number into (pipe, port) pair
    NOTE: For now this is a Tofino-specific method
    """
    return (dp >> 7, dp & 0x7F)

def devport_to_mcport(dp):
    """
    Convert a physical 9-bit (devport) number to the index that is used by 
    MC APIs (for bitmaps mostly)
    NOTE: For now this is a Tofino-specific method
    """
    (pipe, port) = to_pipeport(dp)
    return pipe * 72 + port

def mcport_to_devport(mcport):
    """
    Convert a MC port index (mcport) to devport
    NOTE: For now this is a Tofino-specific method
    """
    return to_devport(mcport / 72, mcport % 72)

def devports_to_mcbitmap(devport_list):
    """
    Convert a list of devports into a Tofino-specific MC bitmap
    """
    bit_map = [0] * ((288 + 7) / 8)
    for dp in devport_list:
        mc_port = devport_to_mcport(dp)
        bit_map[mc_port / 8] |= (1 << (mc_port % 8))
    return bytes_to_string(bit_map)

def mcbitmap_to_devports(mc_bitmap):
    """
    Convert a MC bitmap of mcports to a list of devports
    """
    bit_map = string_to_bytes(mc_bitmap)
    devport_list = []
    for i in range(0, len(bit_map)):
        for j in range(0, 8):
            if bit_map[i] & (1 << j) != 0:
                devport_list.append(mcport_to_devport(i * 8 + j))
    return devport_list

def lags_to_mcbitmap(lag_list):
    """
    Convert a list of LAG indices to a MC bitmap
    """
    bit_map = [0] * ((256 + 7) / 8)
    for lag in lag_list:
        bit_map[lag / 8] |= (1 << (lag % 8))
    return bytes_to_string(bit_map)
    
def mcbitmap_to_lags(mc_bitmap):
    """
    Convert an MC bitmap into a list of LAG indices
    """
    bit_map = string_to_bytes(mc_bitmap)
    lag_list = []
    for i in range(0, len(bit_map)):
        for j in range(0, 8):
            if bit_map[i] & (1 << j) != 0:
                devport_list.append(i * 8 + j)
    return lag_list

############################################################################
################# I N D I V I D U A L    T E S T S #########################
############################################################################

class McTest1(BaseProgramTest):
    # This method represents the test itself. Typically you would want to
    # configure the device (e.g. by populating the tables), send some
    # traffic and check the results.
    #
    # For more flexible checks, you can import unittest module and use
    # the provided methods, such as unittest.assertEqual()
    #
    # Do not enclose the code into try/except/finally -- this is done by
    # the framework itself
    def runTest(self):
        ipv4_dst      = test_param_get("ipv4_dst", "224.0.0.1")
        mgrp_id       = test_param_get("mgrp_id",  1)
        ingress_port  = test_param_get("ingress_port", 0)
        
        no_mod_rid    = test_param_get("no_mod_rid", 5)
        no_mod_ports  = test_param_get("no_mod_ports", [1, 3, 8])

        mod1_rid      = test_param_get("mod1_rid", 10)
        mod1_ports    = test_param_get("mod1_ports", [2, 3, 7, 8])
        mod1_dstmac   = test_param_get("mod1_dstmac", "00:10:11:12:13:14")
        mod1_dstip    = test_param_get("mod1_dstip",  "192.168.23.1")
        mod1_vlan     = test_param_get("mod1_vlan",   10)

        mod2_rid      = test_param_get("mod2_rid", 20)
        mod2_ports    = test_param_get("mod2_ports", [5, 8])
        mod2_dstmac   = test_param_get("mod2_dstmac", "00:11:22:33:44:55")
        mod2_dstip    = test_param_get("mod2_dstip",  "10.11.12.13")

        print("\n")
        print("Test Run")
        print("========")

        # Create the multicast group
        mgrp1 = self.fixed.mc.mc_mgrp_create(self.fixed.mc_sess, self.dev, mgrp_id)
        print("  Created Multicast Group {}".format(mgrp_id))

        # Create the nodes and associate them with the multicast group
        self.fixed.mc.mc_associate_node(
            self.fixed.mc_sess, self.dev,
            mgrp1,
            self.fixed.mc.mc_node_create(
                self.fixed.mc_sess, self.dev,
                no_mod_rid,
                devports_to_mcbitmap(no_mod_ports),
                lags_to_mcbitmap([])),
            xid=0, xid_valid=False)
        print("  Added the node with rid={} and ports {}".format(
            no_mod_rid, no_mod_ports))
        
        self.fixed.mc.mc_associate_node(
            self.fixed.mc_sess, self.dev,
            mgrp1,
            self.fixed.mc.mc_node_create(
                self.fixed.mc_sess, self.dev,
                mod1_rid,
                devports_to_mcbitmap(mod1_ports),
                lags_to_mcbitmap([])),
            xid=0, xid_valid=False)
        print("  Added the node with rid={} and ports {}".format(
            mod1_rid, mod1_ports))        
        
        self.fixed.mc.mc_associate_node(
            self.fixed.mc_sess, self.dev,
            mgrp1,
            self.fixed.mc.mc_node_create(
                self.fixed.mc_sess, self.dev,
                mod2_rid,
                devports_to_mcbitmap(mod2_ports),
                lags_to_mcbitmap([])),
            xid=0, xid_valid=False)
        print("  Added the node with rid={} and ports {}".format(
            mod2_rid, mod2_ports))
        
        self.fixed.mc.mc_complete_operations(self.fixed.mc_sess)
        
        #
        # Program an entry in IPv4: ipv4_dst --> multicast(mgrp_id)
        #
        key_list = [
            self.ipv4_host.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr', ipv4_dst)])
            ]

        data_list = [
            self.ipv4_host.make_data([
                gc.DataTuple('mcast_grp', mgrp_id)], "Ingress.multicast")
            ]

        self.ipv4_host.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_host: {} --> multicast({})".format(
            ipv4_dst, mgrp_id))

        #
        # Create modification entries in mcast_mods table
        #
        key_list = [
            self.mcast_mods.make_key([
                gc.KeyTuple('eg_intr_md.egress_rid', mod1_rid, 0xFFFF),
                gc.KeyTuple('hdr.ipv4.dst_addr', 0, 0),
                gc.KeyTuple('$MATCH_PRIORITY', 0)])
            ]

        data_list = [
            self.mcast_mods.make_data([
                gc.DataTuple('vlan_id', mod1_vlan),
                gc.DataTuple('dstmac',  mod1_dstmac),
                gc.DataTuple('dstip',   mod1_dstip)],
                                     "Egress.modify_packet_vlan")
            ]

        self.mcast_mods.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to mcast_mods: rid={} --> mod1()".format(
            mod1_rid))

        key_list = [
            self.mcast_mods.make_key([
                gc.KeyTuple('eg_intr_md.egress_rid', mod2_rid, 0xFFFF),
                gc.KeyTuple('hdr.ipv4.dst_addr', 0, 0),
                gc.KeyTuple('$MATCH_PRIORITY', 0)])
            ]

        data_list = [
            self.mcast_mods.make_data([
                gc.DataTuple('dstmac',  mod2_dstmac),
                gc.DataTuple('dstip',   mod2_dstip)],
                                     "Egress.modify_packet_no_vlan")
            ]

        self.mcast_mods.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to mcast_mods: rid={} --> mod2()".format(
            mod2_rid))

        #
        # Now, we can create an IP packet with DIP=ipv3_dst and watch it
        # getting replicated and modified
        #
        test_pkt = simple_udp_packet(ip_dst=ipv4_dst, udp_dport=7)
        str_test_pkt = str(test_pkt)

        # Create the expected packets:
        #   no_mod_pkt -- without modifications,
        #    mod1_pkt  -- with VLAN tag spliced in plus modified MAC DA and DIP
        #    mod2_pkt  -- with modified MAC DA and DIP
        # Note:
        # For simple_l3_mcast, modified packets will have incorrect
        # IPv4 and UDP checksum, because the P4 program does not contain
        # checksum update code
        # For simple_l3_mcast_checksum, modifid packets should have correct
        # checksum
        no_mod_pkt = Ether(str_test_pkt)
        
        if self.checksum:
            mod1_pkt = copy.deepcopy(test_pkt[Ether])
            mod1_pkt = (Ether(src=test_pkt[Ether].src, dst=test_pkt[Ether].dst)/
                        Dot1Q()/
                        copy.deepcopy(test_pkt[Ether].payload))
        else:
            mod1_pkt = Ether(str_test_pkt[0:14])/Dot1Q()/IP(str_test_pkt[14:])
        mod1_pkt[Ether].dst  = mod1_dstmac
        mod1_pkt[Ether].type = 0x8100
        mod1_pkt[Dot1Q].vlan = mod1_vlan
        mod1_pkt[IP].dst     = mod1_dstip

        if self.checksum:
            mod2_pkt   = copy.deepcopy(test_pkt)
        else:
            mod2_pkt   = Ether(str_test_pkt)
        mod2_pkt[Ether].dst = mod2_dstmac
        mod2_pkt[IP].dst    = mod2_dstip

        # Create the list of all expected packets.
        exp_pkt_list      = []
        exp_pkt_type_list = []
        for port in no_mod_ports:
            exp_pkt_list.append((self.dev, port, str(no_mod_pkt), "no_mod"))
        for port in mod1_ports:
            exp_pkt_list.append((self.dev, port, str(mod1_pkt), "mod1"))
        for port in mod2_ports:
            exp_pkt_list.append((self.dev, port, str(mod2_pkt), "mod2"))
            
        print("  Expecting {} packets in any order".format(len(exp_pkt_list)))
        for (exp_dev, exp_port, exp_pkt, exp_pkt_type) in exp_pkt_list:
            print("    {:<6} packet on port {}".format(exp_pkt_type, exp_port))
        print

        # Send the test packet now
        print("  Sending Test Packet into port %d" % ingress_port)
        send_packet(self, ingress_port, test_pkt)

        print("  Receiving packets...")
        found_count = 0
        while True:
            # Receive a packet using a lower-level routine
            result = dp_poll(self, self.dev, timeout=1)
            if isinstance(result, self.dataplane.PollSuccess):
                rcv_pkt = str(result.packet)
                rcv_port = result.port
                found = False

                # Check if the packet was expected (is in the list)
                i = 0
                for (exp_dev, exp_port, exp_pkt, exp_pkt_type) in exp_pkt_list:
                    if exp_port == rcv_port and match_exp_pkt(exp_pkt, rcv_pkt):
                        found = True
                        break
                    else:
                        i += 1
                        
                if found:
                    found_count += 1
                    print("    {:<6} packet on port {}".format(
                        exp_pkt_type, rcv_port))
                    del(exp_pkt_list[i])
                else:
                    print("Received unexpected packet on port {}".format(
                        rcv_port))
                    Ether(rcv_pkt).show()
                    self.assertTrue(found)
            else:
                break
        self.assertTrue(len(exp_pkt_list) == 0)
