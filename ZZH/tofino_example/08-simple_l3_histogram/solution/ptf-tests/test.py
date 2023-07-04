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
from __future__ import print_function


"""
Simple PTF test for simple_l3_histogram
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
    def setUp(self):
        self.client_id = 0
        self.p4_name = "simple_l3_histogram"
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

        self.packet_size_hist = self.bfrt_info.table_get(
                                                 "Egress.packet_size_hist")
        
        self.tables = [ self.ipv4_host, self.ipv4_lpm, self.packet_size_hist]

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

class Test1(BaseProgramTest):
    def runTest(self):
        # Test Parameters
        ipv4_dst     = test_param_get("ipv4_dst", "192.168.1.1")
        ingress_port = test_param_get("ingress_port", 0)
        ranges       = test_param_get("ranges",
                                      [0, 64, 128, 256, 512, 1024, 1536, 2048])

        pkt_count    = test_param_get("pkt_count", 100)
        egress_port  = test_param_get("egress_port", 1)

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

        self.ipv4_host.entry_add(self.dev_tgt, key_list, data_list)
        print("  Added an entry to ipv4_host: {} --> send({})".format(
            ipv4_dst, egress_port))

        #
        # Program the ranges in packet_size_hist 
        #
        key_list = [
            self.packet_size_hist.make_key([
                gc.KeyTuple('eg_intr_md.pkt_length',
                            low=ranges[i], high=ranges[i + 1] - 1),
                gc.KeyTuple('$MATCH_PRIORITY', 0)])
            for i in range(len(ranges)-1)
            ]

        data_list = [
            self.packet_size_hist.make_data([], 'Egress.just_count')
            for i in range(len(ranges)-1)
            ]
        self.packet_size_hist.entry_add(self.dev_tgt, key_list, data_list)
        print("  Added histogram entries for the following ranges:")
        for i in range(len(ranges)-1):
            print("      {:>5} .. {:>5} ".format(ranges[i], ranges[i + 1] - 1))
                                            
        #
        # Send test packets
        #
        max_pkt_len = ranges[-1] - 5 # Since there will be 4 bytes of FCS
        print("Sending {} packets with random lengths 0(64)... {} into port {}".
              format(pkt_count, max_pkt_len, ingress_port))
        print("All packets are expected to be received on port {}".
              format(egress_port))
        
        packet_counts = [0] * len(ranges)
        
        for i in range(0, pkt_count):
            pktlen = random.randint(0, max_pkt_len)
            if pktlen < 60:           # Should be 60 for the real HW
                pktlen = 60           #
            real_pkt_len = pktlen + 4 # Do not forget about FCS
            for j in range(len(ranges) - 1):
                low  = ranges[j]
                high = ranges[j + 1] - 1
                if low <= real_pkt_len <= high:
                    packet_counts[j] += 1
                    break

            data, _ = next(self.packet_size_hist.entry_get(
                self.dev_tgt,
                [ self.packet_size_hist.make_key([
                    gc.KeyTuple('eg_intr_md.pkt_length', low=low, high=high),
                    gc.KeyTuple('$MATCH_PRIORITY', 0)])],
	        flags = {"from_hw": True}))
            counter_before = data.to_dict()["$COUNTER_SPEC_PKTS"]
                            
            print("Sending {:5}({:5}) byte packet ... ".
                  format(pktlen, real_pkt_len),
                  end='')
            
            pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                    eth_src='00:55:55:55:55:55',
                                    ip_dst=ipv4_dst,
                                    ip_id=101,
                                    ip_ttl=64,
                                    ip_ihl=5,
                                    pktlen=pktlen)
            send_packet(self, ingress_port, pkt)
            verify_packet(self, pkt, egress_port)
            print("OK", end='   ')

            data, _ = next(self.packet_size_hist.entry_get(
                self.dev_tgt,
                [ self.packet_size_hist.make_key([
                    gc.KeyTuple('eg_intr_md.pkt_length', low=low, high=high),
                    gc.KeyTuple('$MATCH_PRIORITY', 0)])],
	        flags = {"from_hw": True}))
            counter_after = data.to_dict()["$COUNTER_SPEC_PKTS"]
                            
            print("Match entry {:5}..{:5}: {:5} --> {:5}".
                  format(low, high, counter_before, counter_after),
                  end='\r')
            sys.stdout.flush()
            
            self.assertEqual(counter_before + 1, counter_after)

        print()
        
        # Final Verification
        print("Our Counts:")
        print("-----------")
        for i in range(len(ranges) - 1):
            low  = ranges[i]
            high = ranges[i+1]-1
            print("  {:5} .. {:5}  -->  {} packets".
                  format(low, high, packet_counts[i]))
        
        print("Chip Counts:")
        print("------------")
        i = 0
        for data, key in self.packet_size_hist.entry_get(
                self.dev_tgt, key_list, flags = {"from_hw": True}):
            print("  {:5} .. {:5}  -->  {} packets".
                  format(
                      key.to_dict()["eg_intr_md.pkt_length"]["low"],
                      key.to_dict()["eg_intr_md.pkt_length"]["low"],
                      data.to_dict()["$COUNTER_SPEC_PKTS"]))
            self.assertEqual(data.to_dict()["$COUNTER_SPEC_PKTS"],
                             packet_counts[i])
            i = i + 1
