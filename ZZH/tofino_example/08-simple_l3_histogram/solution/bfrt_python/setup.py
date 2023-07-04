from ipaddress import ip_address

p4 = bfrt.simple_l3_histogram.pipe

# This function can clear all the tables and later on other fixed objects
# once bfrt support is added.
def clear_all():
    global p4

    # The order is important. We do want to clear from the top, i.e.
    # delete objects that use other objects, e.g. table entries use
    # selector groups and selector groups use action profile members
    
    # Clear Match Tables
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR']: 
            print("Clearing table {}".format(table['full_name']))
            for entry in table['node'].get(regex=True):
                entry.remove()
    # Clear Selectors
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['SELECTOR']:
            print("Clearing ActionSelector {}".format(table['full_name']))
            for entry in table['node'].get(regex=True):
                entry.remove()
    # Clear Action Profiles
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['ACTION_PROFILE']:
            print("Clearing ActionProfile {}".format(table['full_name']))
            for entry in table['node'].get(regex=True):
                entry.remove()
    
clear_all()

ipv4_host = p4.Ingress.ipv4_host
ipv4_host.add_with_send(dst_addr=ip_address('192.168.1.1'),   port=1)
ipv4_host.add_with_send(dst_addr=ip_address('192.168.1.2'),   port=2)
ipv4_host.add_with_drop(dst_addr=ip_address('192.168.1.3'))
ipv4_host.add_with_send(dst_addr=ip_address('192.168.1.254'), port=64)

ipv4_lpm =  p4.Ingress.ipv4_lpm
ipv4_lpm.add_with_send(
    dst_addr=ip_address('192.168.1.0'), dst_addr_p_length=24, port=1)
ipv4_lpm.add_with_drop(
    dst_addr=ip_address('192.168.0.0'), dst_addr_p_length=16)
ipv4_lpm.add_with_send(
    dst_addr=ip_address('0.0.0.0'),     dst_addr_p_length=0,  port=64)

packet_size_hist = p4.Egress.packet_size_hist

# All entries below will have the same match_priority=0. If you want to use
# overlapping ranges, match_priority must be explicitly specified
packet_size_hist.add_with_just_count(pkt_length_start=0,    pkt_length_end=63)
packet_size_hist.add_with_just_count(pkt_length_start=64,   pkt_length_end=127)
packet_size_hist.add_with_just_count(pkt_length_start=128,  pkt_length_end=255)
packet_size_hist.add_with_just_count(pkt_length_start=256,  pkt_length_end=511)
packet_size_hist.add_with_just_count(pkt_length_start=512,  pkt_length_end=1023)
packet_size_hist.add_with_just_count(pkt_length_start=1024, pkt_length_end=1522)
packet_size_hist.add_with_just_count(pkt_length_start=1523, pkt_length_end=16384)

# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")
print ("Table ipv4_host:")
ipv4_host.dump(table=True)
print ("Table ipv4_lpm:")
ipv4_lpm.dump(table=True)
print ("Table packet_size_hist:")
packet_size_hist.dump(table=True)

