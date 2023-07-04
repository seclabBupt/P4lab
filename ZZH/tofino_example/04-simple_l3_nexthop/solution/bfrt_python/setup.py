from ipaddress import ip_address

p4 = bfrt.simple_l3_nexthop.pipe

# Clear All tables
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

# nexthop
nexthop = p4.Ingress.nexthop

nexthop.add_with_send(nexthop_id=0, port=64)
nexthop.add_with_drop(nexthop_id=1)

nexthop.add_with_l3_switch(
    nexthop_id=100,
    new_mac_da=0x000001000001, new_mac_sa=0x0000FF0000FE, port=3)

nexthop.add_with_l3_switch(
    nexthop_id=101,
    new_mac_da=0x000002000001, new_mac_sa=0x00123456789A, port=4)

# ipv4_host
ipv4_host = p4.Ingress.ipv4_host

ipv4_host.add_with_set_nexthop(
    dst_addr=ip_address('192.168.1.1'), nexthop=100)

ipv4_host.add_with_set_nexthop(
    dst_addr=ip_address('192.168.1.2'), nexthop=101)

ipv4_host.add_with_set_nexthop(
    dst_addr=ip_address('192.168.1.3'), nexthop=102) # Doesn't exist!

# ipv4_lpm
ipv4_lpm = p4.Ingress.ipv4_lpm

ipv4_lpm.add_with_set_nexthop(
    dst_addr=ip_address('192.168.1.0'), dst_addr_p_length=24, nexthop=0)

ipv4_lpm.add_with_set_nexthop(
    dst_addr=ip_address('192.168.3.0'), dst_addr_p_length=24, nexthop=100)

ipv4_lpm.add_with_set_nexthop(
    dst_addr=ip_address('192.168.5.0'), dst_addr_p_length=24, nexthop=101)

ipv4_lpm.add_with_set_nexthop(
    dst_addr=ip_address('192.168.7.0'), dst_addr_p_length=24, nexthop=100)

ipv4_lpm.add_with_set_nexthop(
    dst_addr=ip_address('192.168.0.0'), dst_addr_p_length=16, nexthop=1)

ipv4_lpm.set_default_with_set_nexthop(nexthop=0)

bfrt.complete_operations()

# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")
print ("\nTable nexthop:")
nexthop.dump(table=True)
print ("\nTable ipv4_host:")
ipv4_host.dump(table=True)
print ("\nTable ipv4_lpm:")
ipv4_lpm.dump(table=True)

