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
Simple PTF test for simple_l3_lag_ecmp
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
    #     etc...
    def setUp(self):
        self.client_id = 0
        self.p4_name   = "simple_l3_lag_ecmp" 
        self.dev       = 0
        self.dev_tgt   = gc.Target(self.dev, pipe_id=0xFFFF)

        print("\n")
        print("Test Setup")
        print("==========")

        BfRuntimeTest.setUp(self, self.client_id, self.p4_name)
        self.bfrt_info = self.interface.bfrt_info_get(self.p4_name)

        # Create a list of all ports available on the device
        self.swports = []
        for (device, port, ifname) in ptf.config['interfaces']:
            self.swports.append(port)

            self.swports.sort()
            
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

        self.ipv6_host = self.bfrt_info.table_get("Ingress.ipv6_host")
        self.ipv6_host.info.key_field_annotation_add(
            "hdr.ipv6.dst_addr", "ipv6")

        self.ipv6_lpm = self.bfrt_info.table_get("Ingress.ipv6_lpm")
        self.ipv6_lpm.info.key_field_annotation_add(
            "hdr.ipv6.dst_addr", "ipv6")

        self.nexthop      = self.bfrt_info.table_get("Ingress.nexthop")
        self.lag_ecmp_sel = self.bfrt_info.table_get("Ingress.lag_ecmp_sel")
        self.lag_ecmp     = self.bfrt_info.table_get("Ingress.lag_ecmp")

        self.tables = [ self.ipv4_host, self.ipv4_lpm,
                        self.ipv6_host, self.ipv6_lpm,
                        self.nexthop,
                        self.lag_ecmp_sel,
                        self.lag_ecmp ]

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
                for (d, k) in t.entry_get(self.dev_tgt,
                                          flags={"from_hw": False}):
                    if k is not None:
                        keys.append(k)
                        
                t.entry_del(self.dev_tgt, keys)
                
                # Not all tables support default entry. This is a heuristic
                # that we can use until relevant information will be added to
                # table_info
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
        print("=============")
        
        self.cleanUp()
        
        # Call the Parent tearDown
        BfRuntimeTest.tearDown(self)

#
# Individual tests can now be subclassed from SimpleL3
#

########################################################################
########    Running Multiple Tests with the same setup   ###############
########################################################################

import ipaddress  # For easy IP address increment

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
        self.egress_ports = test_param_get("egress_ports", [1,2,3])
        self.nexthop_id   = test_param_get("nexthop_id",   100)
        self.group_id     = test_param_get("group_id",     2000)
        self.first_mbr_id = test_param_get("first_mbr_id", 200000)

        # Do not forget to call parent class setup first!
        BaseProgramTest.setUp(self)

        #Create the members
        self.programTable(self.lag_ecmp,[
            ([("$ACTION_MEMBER_ID", self.first_mbr_id + mbr)],
              "Ingress.send", [("port", self.egress_ports[mbr])])
            for mbr in range(len(self.egress_ports))])
                          
        #Create the group
        self.programTable(self.lag_ecmp_sel, [
            ([("$SELECTOR_GROUP_ID", self.group_id)],
             None,
             [("$MAX_GROUP_SIZE", ((len(self.egress_ports)-1)/120+1) * 120),
              ("$ACTION_MEMBER_ID", None, None, None,
               [self.first_mbr_id + mbr for mbr in range(len(self.egress_ports))]),
              ("$ACTION_MEMBER_STATUS", None, None, None, None,
               [True for mbr in range(len(self.egress_ports))])
              ])
            ])

        # Create the nexthop
        self.programTable(self.nexthop, [
            ([("nexthop_id", self.nexthop_id)],
             None, [("$SELECTOR_GROUP_ID", self.group_id)])
            ])
        
        # Program default route in ipv4 lpm to point to self.nexthop_id
        self.programTable(self.ipv4_lpm, [
            ([("hdr.ipv4.dst_addr", "0.0.0.0", None, 0)],
             "Ingress.set_nexthop", [("nexthop", self.nexthop_id)])
            ])

        # Program default route in ipv4 lpm to point to self.nexthop_id
        self.programTable(self.ipv6_lpm, [
            ([("hdr.ipv6.dst_addr", "::", None, 0)],
             "Ingress.set_nexthop", [("nexthop", self.nexthop_id)])
            ])

#
# The following are multiple tests that all use the same setup
#
class LagIPv4Random(TestGroup1):
    def runTest(self):
        # Test Parameters
        ingress_port   = test_param_get("ingress_port", 0)
        pkt_count      = test_param_get("pkt_count", 100)
        seed           = test_param_get("seed", 0)
        max_imbalance  = test_param_get("max_imbalance", 10)

        egress_ports   = self.egress_ports

        #
        # Send Packets
        #
        random.seed(seed)
        packet_counts = [0] * len(egress_ports)
        for i in range(0, pkt_count * len(egress_ports)):
            dst_ip=".".join(["%d" % random.randint(1, 255) for x in range(4)])
            src_ip=".".join(["%d" % random.randint(1, 255) for x in range(4)])
            tcp = random.randint(0,1)
            sport = random.randint(0, 65535)
            dport = random.randint(0, 65535)

            if tcp == 1:
                proto="TCP"
                pkt = simple_tcp_packet(ip_dst=dst_ip,
                                        ip_src=src_ip,
                                        tcp_sport=sport,
                                        tcp_dport=dport)
            else:
                proto="UDP"
                pkt = simple_udp_packet(ip_dst=dst_ip,
                                        ip_src=src_ip,
                                        udp_sport=sport,
                                        udp_dport=dport)

            send_packet(self, ingress_port, pkt)
            (port_idx, result) = verify_packet_any_port(self, pkt, egress_ports)
            self.assertTrue(port_idx < len(egress_ports))
            packet_counts[port_idx] += 1

            print "{:s} {:>15s}.{:<5d} -> {:>15s}.{:<5d}: {:>3d} {}\r".format(
                proto, src_ip, sport, dst_ip, dport, egress_ports[port_idx],
                packet_counts),
            sys.stdout.flush()

        print
        #
        # Print summary results and check
        #
        total_pkts = 0
        for i in range(0, len(egress_ports)):
            print "Port %3d: %5d packets" % (egress_ports[i], packet_counts[i])
            total_pkts += packet_counts[i]
        print "Total: %d" % total_pkts

        self.assertEqual(total_pkts, pkt_count * len(egress_ports))

        max_port_count = max(packet_counts)
        min_port_count = min(packet_counts)
        imbalance = max(pkt_count - min_port_count, max_port_count - pkt_count)
        imbalance_pct = float(imbalance)/pkt_count
        
        print "Max Imbalance: {}/{} packets ({:%})".format(
            imbalance, pkt_count, imbalance_pct)
        
        self.assertTrue(imbalance_pct <= max_imbalance)
            

class LagIPv4Seq(TestGroup1):
    def runTest(self):
        # Test Parameters
        ingress_port = test_param_get("ingress_port", 0)
        pkt_count    = test_param_get("pkt_count", 100)

        dst_ip       = test_param_get("dst_ip", "192.168.1.1")
        dst_ip_inc   = test_param_get("dst_ip_inc", 1)
        src_ip       = test_param_get("src_ip", "10.0.0.1")
        src_ip_inc   = test_param_get("src_ip_inc", 1)
        sport        = test_param_get("sport", 1024)
        sport_inc    = test_param_get("sport_inc", 1)
        dport        = test_param_get("dport", 1)
        dport_inc    = test_param_get("dport_inc", 1)
        
        seed         = test_param_get("seed", 0)
        max_imbalance  = test_param_get("max_imbalance", 10)

        egress_ports = self.egress_ports
        
        #
        # Send Packets
        #
        random.seed(seed)
        packet_counts = [0] * len(egress_ports)
        for i in range(0, pkt_count * len(egress_ports)):
            pkt = simple_tcp_packet(ip_dst=dst_ip,
                                    ip_src=src_ip,
                                    tcp_sport=sport,
                                    tcp_dport=dport)
            send_packet(self, ingress_port, pkt)
            (port_idx, result) = verify_packet_any_port(self, pkt, egress_ports)
            self.assertTrue(port_idx < len(egress_ports))
            packet_counts[port_idx] += 1
            print "{:>15s}.{:<5d} -> {:>15s}.{:<5d}: {:>3d} {}\r".format(
                src_ip, sport, dst_ip, dport, egress_ports[port_idx],
                packet_counts),
            sys.stdout.flush()


            # Increment
            dst_ip = str(ipaddress.ip_address(dst_ip.decode()) +  dst_ip_inc)
            src_ip = str(ipaddress.ip_address(src_ip.decode()) +  src_ip_inc)
            dport += dport_inc; dport %= 65536
            sport += sport_inc; sport %= 65536

        print
        
        #
        # Print summary results and check
        #
        total_pkts = 0
        for i in range(0, len(egress_ports)):
            print "Port %3d: %5d packets" % (egress_ports[i], packet_counts[i])
            total_pkts += packet_counts[i]
        print "Total: %d" % total_pkts

        self.assertEqual(total_pkts, pkt_count * len(egress_ports))

        max_port_count = max(packet_counts)
        min_port_count = min(packet_counts)
        imbalance = max(pkt_count - min_port_count, max_port_count - pkt_count)
        imbalance_pct = float(imbalance)/pkt_count
        
        print "Max Imbalance: {}/{} packets ({:%})".format(
            imbalance, pkt_count, imbalance_pct)
        
        self.assertTrue(imbalance_pct <= max_imbalance)

class LagIPv4Random(TestGroup1):
    def runTest(self):
        # Test Parameters
        ingress_port   = test_param_get("ingress_port", 0)
        pkt_count      = test_param_get("pkt_count", 100)
        seed           = test_param_get("seed", 0)
        max_imbalance  = test_param_get("max_imbalance", 10)

        egress_ports   = self.egress_ports

        #
        # Send Packets
        #
        random.seed(seed)
        packet_counts = [0] * len(egress_ports)
        for i in range(0, pkt_count * len(egress_ports)):
            dst_ip=".".join(["%d" % random.randint(1, 255) for x in range(4)])
            src_ip=".".join(["%d" % random.randint(1, 255) for x in range(4)])
            tcp = random.randint(0,1)
            sport = random.randint(0, 65535)
            dport = random.randint(0, 65535)

            if tcp == 1:
                proto="TCP"
                pkt = simple_tcp_packet(ip_dst=dst_ip,
                                        ip_src=src_ip,
                                        tcp_sport=sport,
                                        tcp_dport=dport)
            else:
                proto="UDP"
                pkt = simple_udp_packet(ip_dst=dst_ip,
                                        ip_src=src_ip,
                                        udp_sport=sport,
                                        udp_dport=dport)

            send_packet(self, ingress_port, pkt)
            (port_idx, result) = verify_packet_any_port(self, pkt, egress_ports)
            self.assertTrue(port_idx < len(egress_ports))
            packet_counts[port_idx] += 1

            print "{:s} {:>15s}.{:<5d} -> {:>15s}.{:<5d}: {:>3d} {}\r".format(
                proto, src_ip, sport, dst_ip, dport, egress_ports[port_idx],
                packet_counts),
            sys.stdout.flush()

        print
        #
        # Print summary results and check
        #
        total_pkts = 0
        for i in range(0, len(egress_ports)):
            print "Port %3d: %5d packets" % (egress_ports[i], packet_counts[i])
            total_pkts += packet_counts[i]
        print "Total: %d" % total_pkts

        self.assertEqual(total_pkts, pkt_count * len(egress_ports))

        max_port_count = max(packet_counts)
        min_port_count = min(packet_counts)
        imbalance = max(pkt_count - min_port_count, max_port_count - pkt_count)
        imbalance_pct = float(imbalance)/pkt_count
        
        print "Max Imbalance: {}/{} packets ({:%})".format(
            imbalance, pkt_count, imbalance_pct)
        
        self.assertTrue(imbalance_pct <= max_imbalance)
            

class LagIPv6Random(TestGroup1):
    def runTest(self):
        # Test Parameters
        ingress_port   = test_param_get("ingress_port", 0)
        pkt_count      = test_param_get("pkt_count", 100)
        seed           = test_param_get("seed", 0)
        max_imbalance  = test_param_get("max_imbalance", 10)

        egress_ports   = self.egress_ports

        #
        # Send Packets
        #
        random.seed(seed)
        packet_counts = [0] * len(egress_ports)
        for i in range(0, pkt_count * len(egress_ports)):
            dst_ip=":".join(["%04x" % random.randint(1, 65535) for x in range(8)])
            src_ip=":".join(["%04x" % random.randint(1, 65535) for x in range(8)])
            tcp = random.randint(0,1)
            sport = random.randint(0, 65535)
            dport = random.randint(0, 65535)

            if tcp == 1:
                proto="TCP"
                pkt = simple_tcpv6_packet(ipv6_dst=dst_ip,
                                          ipv6_src=src_ip,
                                          tcp_sport=sport,
                                          tcp_dport=dport)
            else:
                proto="UDP"
                pkt = simple_udpv6_packet(ipv6_dst=dst_ip,
                                          ipv6_src=src_ip,
                                          udp_sport=sport,
                                          udp_dport=dport)

            send_packet(self, ingress_port, pkt)
            (port_idx, result) = verify_packet_any_port(self, pkt, egress_ports)
            self.assertTrue(port_idx < len(egress_ports))
            packet_counts[port_idx] += 1

            print "{:s} {:>15s}.{:<5d} -> {:>15s}.{:<5d}: {:>3d} {}\r".format(
                proto, src_ip, sport, dst_ip, dport, egress_ports[port_idx],
                packet_counts),
            sys.stdout.flush()

        print
        #
        # Print summary results and check
        #
        total_pkts = 0
        for i in range(0, len(egress_ports)):
            print "Port %3d: %5d packets" % (egress_ports[i], packet_counts[i])
            total_pkts += packet_counts[i]
        print "Total: %d" % total_pkts

        self.assertEqual(total_pkts, pkt_count * len(egress_ports))

        max_port_count = max(packet_counts)
        min_port_count = min(packet_counts)
        imbalance = max(pkt_count - min_port_count, max_port_count - pkt_count)
        imbalance_pct = float(imbalance)/pkt_count
        
        print "Max Imbalance: {}/{} packets ({:%})".format(
            imbalance, pkt_count, imbalance_pct)
        
        self.assertTrue(imbalance_pct <= max_imbalance)

class LagIPv6Seq(TestGroup1):
    def runTest(self):
        # Test Parameters
        ingress_port = test_param_get("ingress_port", 0)
        pkt_count    = test_param_get("pkt_count", 100)

        dst_ip       = test_param_get("dst_ipv6", '2001:db8:85a3::8a2e:370:7334')
        dst_ip_inc   = test_param_get("dst_ip_inc", 1)
        src_ip       = test_param_get("src_ipv6", "fe80::98b5:89d2:f18a:927b")
        src_ip_inc   = test_param_get("src_ip_inc", 1)
        sport        = test_param_get("sport", 1024)
        sport_inc    = test_param_get("sport_inc", 1)
        dport        = test_param_get("dport", 1)
        dport_inc    = test_param_get("dport_inc", 1)
        
        seed         = test_param_get("seed", 0)
        max_imbalance  = test_param_get("max_imbalance", 10)

        egress_ports = self.egress_ports
        
        #
        # Send Packets
        #
        random.seed(seed)
        packet_counts = [0] * len(egress_ports)
        for i in range(0, pkt_count * len(egress_ports)):
            pkt = simple_tcpv6_packet(ipv6_dst=dst_ip,
                                      ipv6_src=src_ip,
                                      tcp_sport=sport,
                                      tcp_dport=dport)
            send_packet(self, ingress_port, pkt)
            (port_idx, result) = verify_packet_any_port(self, pkt, egress_ports)
            self.assertTrue(port_idx < len(egress_ports))
            packet_counts[port_idx] += 1
            print "{:>15s}.{:<5d} -> {:>15s}.{:<5d}: {:>3d} {}\r".format(
                src_ip, sport, dst_ip, dport, egress_ports[port_idx],
                packet_counts),
            sys.stdout.flush()


            # Increment
            dst_ip = str(ipaddress.ip_address(dst_ip.decode()) +  dst_ip_inc)
            src_ip = str(ipaddress.ip_address(src_ip.decode()) +  src_ip_inc)
            dport += dport_inc; dport %= 65536
            sport += sport_inc; sport %= 65536

        print
        
        #
        # Print summary results and check
        #
        total_pkts = 0
        for i in range(0, len(egress_ports)):
            print "Port %3d: %5d packets" % (egress_ports[i], packet_counts[i])
            total_pkts += packet_counts[i]
        print "Total: %d" % total_pkts

        self.assertEqual(total_pkts, pkt_count * len(egress_ports))

        max_port_count = max(packet_counts)
        min_port_count = min(packet_counts)
        imbalance = max(pkt_count - min_port_count, max_port_count - pkt_count)
        imbalance_pct = float(imbalance)/pkt_count
        
        print "Max Imbalance: {}/{} packets ({:%})".format(
            imbalance, pkt_count, imbalance_pct)
        
        self.assertTrue(imbalance_pct <= max_imbalance)
