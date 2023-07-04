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
Basic functional tests for the program simple_l3.p4
"""

# The simple_l3_mpls.py file in the same directory
# contains the foundational class, that is used for these individual tests

from simple_l3_mpls import *


############################################################################
################# I N D I V I D U A L    T E S T S #########################
############################################################################

class LpmMpls1Encap(P4ProgramTest):
    """
    Basic forwarding (send() action) via ipv4_host table
    """
    
    # The runTest() method represents the test itself. 
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
        egress_port  = test_param_get("egress_port",   4)
        ipv4_addr    = test_param_get("ipv4_addr",     "192.168.1.1")
        lpm_addr     = test_param_get("lpm_addr",      "192.168.1.0/24")
        label1       = test_param_get("label1",     1234)

        (lpm_ipv4, lpm_p_len) = lpm_addr.split("/")

        print("\n")
        print("Test Run")
        print("========")

        #
        # Program an entry in IPv4: ipv4_dst -->
        #                                 mpls_1_encap(egress_port, label1)
        #
        key_list = [
            self.ipv4_lpm.make_key([
                gc.KeyTuple('hdr.ipv4.dst_addr',
                            value=lpm_ipv4, prefix_len=int(lpm_p_len))])
            ]

        data_list = [
            self.ipv4_lpm.make_data([
                gc.DataTuple('port', egress_port),
                gc.DataTuple('label1', label1)],
                "Ingress.mpls_1_encap")
            ]

        self.ipv4_lpm.entry_add(self.dev_tgt, key_list, data_list);
        print("  Added an entry to ipv4_lpm: {} --> mpls_1_encap({}, {})".
              format(lpm_addr, egress_port, label1))

        #
        # Send a test packet
        #
        send_pkt = simple_tcp_packet(eth_dst="00:98:76:54:32:10",
                                eth_src='00:55:55:55:55:55',
                                ip_dst=ipv4_addr,
                                ip_id=101,
                                ip_ttl=64,
                                ip_ihl=5)
        print("  Sending packet with IPv4 DST ADDR={} into port {}\n{}".
              format(ipv4_addr, ingress_port, repr(send_pkt)))
        
        send_packet(self, ingress_port, send_pkt)

        #
        # Wait for the egress packet and verify it
        #
        exp_pkt = copy.deepcopy(send_pkt)
        exp_pkt[Ether].payload = MPLS(label=label1, ttl=10)/exp_pkt[Ether].payload
        print("\n  Expecting the packet on port {} with MPLS label {}\n{}".
              format(egress_port, label1, repr(exp_pkt)))
        verify_packet(self, exp_pkt, egress_port)
        print("  Packet received of port %d" % egress_port)

        ############# That's it! ###############

