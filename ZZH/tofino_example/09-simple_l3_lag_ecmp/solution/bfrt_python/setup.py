from ipaddress import ip_address

p4 = bfrt.simple_l3_lag_ecmp.pipe

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

# Add Action Profile Members (destinations)
lag_ecmp = p4.Ingress.lag_ecmp

# Workaround for the issue with MATCH_INDIRECT_SEL tables
# lag_ecmp.add_with_drop(0);

port_1_1 = 1;  lag_ecmp.add_with_send(port_1_1, port=1)
port_1_2 = 2;  lag_ecmp.add_with_send(port_1_2, port=1)
port_2   = 20; lag_ecmp.add_with_send(port_2,   port=2)
port_3   = 30; lag_ecmp.add_with_send(port_3,   port=3)

# Creating LAGs or ECMPs by adding entries to lag_ecmp_sel table
lag_ecmp_sel = p4.Ingress.lag_ecmp_sel

# Workaround for the issue with MATCH_INDIRECT_SEL tables
#lag_ecmp_sel.entry(0,
#                   max_group_size=1,
#                   action_member_id=[0], action_member_status=[True]).push()

# For now, this table does not provide an "add" method. Thus we need to create
# an entry and push() it
lag_1 = 1;
lag_ecmp_sel.entry(selector_group_id=lag_1,
                   max_group_size=8,
                   action_member_id=[port_1_1, port_1_2, port_2, port_3],
                   action_member_status=[True, True, True, True]).push()

# nexthop
nexthop = p4.Ingress.nexthop

nexthop.add(nexthop_id=101, action_member_id=port_1_1)
nexthop.add(nexthop_id=102, selector_group_id=lag_1)

# ipv4_host
ipv4_host = p4.Ingress.ipv4_host

ipv4_host.add_with_set_nexthop(
    dst_addr=ip_address('192.168.1.1'), nexthop=101)

ipv4_host.add_with_set_nexthop(
    dst_addr=ip_address('192.168.1.2'), nexthop=102)


# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")

print ("ActionProfile lag_ecmp:")
lag_ecmp.dump(table=True)
print ("ActionSelector lag_ecmp_sel:")
lag_ecmp_sel.dump(table=True)
print ("Table nexthop:")
nexthop.dump(table=True)
print ("Table ipv4_host:")
ipv4_host.dump(table=True)
