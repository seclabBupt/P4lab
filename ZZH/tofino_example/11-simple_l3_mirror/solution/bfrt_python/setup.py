# This is neeeded to execure "run_pd_rpc"
from ipaddress import ip_address
p4 = bfrt.simple_l3_mirror.pipe

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

# Mirror sessions as per ../run_pd_rpc/setup.py
cpu_mirror   = 5
port3_mirror = 7
port5_trunc  = 9

#
# Here we decide what to mirror, based on the ingress port
#
port_acl = p4.Ingress.port_acl

port_acl.add_with_acl_drop_and_mirror(ingress_port=0, ingress_port_mask=0x1FF,
                                      mirror_session = cpu_mirror)
port_acl.add_with_acl_mirror(ingress_port=1, ingress_port_mask=0x1FF,
                             mirror_session = port3_mirror)
port_acl.add_with_acl_mirror(ingress_port=2, ingress_port_mask=0x1FF,
                             mirror_session = port5_trunc)

#
# Here we choose packet treatment
#
mirror_dest = p4.Egress.mirror_dest
mirror_dest.add_with_send_to_cpu(mirror_session=cpu_mirror)
mirror_dest.add_with_just_send(mirror_session=port3_mirror)
mirror_dest.add_with_send_to_cpu(mirror_session=port5_trunc)

# Final programming
print("******************* PROGAMMING RESULTS *****************")
for t in ["ipv4_host", "ipv4_lpm", "nexthop", "port_acl", "mirror_dest"]:
    print ("\nTable {}:".format(t))
    exec("{}.dump(table=True)".format(t))

                       
#
# Here goes mirroring stuff. REMEMBER: mirror sessions are programmed by
# run_pd_rpc!
#
import os
os.environ['SDE_INSTALL'] = os.path.split(os.environ['PATH'].split(":")[0])[0]
os.environ['SDE']         = os.path.split(os.environ['SDE_INSTALL'])[0]

def run_pd_rpc(cmd_or_code, no_print=False):
    """
    This function invokes run_pd_rpc.py tool. It has a single string argument
    cmd_or_code that works as follows:
       If it is a string:
            * if the string starts with os.sep, then it is a filename
            * otherwise it is a piece of code (passed via "--eval"
       Else it is a list/tuple and it is passed "as-is"

    Note: do not attempt to run the tool in the interactive mode!
    """
    import subprocess
    path = os.path.join(os.environ['HOME'], "tools", "run_pd_rpc.py")
    
    command = [path]
    if isinstance(cmd_or_code, str):
        if cmd_or_code.startswith(os.sep):
            command.extend(["--no-wait", cmd_or_code])
        else:
            command.extend(["--no-wait", "--eval", cmd_or_code])
    else:
        command.extend(cmd_or_code)
        
    result = subprocess.check_output(command).decode("utf-8")[:-1]
    if not no_print:
        print(result)
        
    return result

print("\nMirror Session Configuration:")
run_pd_rpc(os.path.join(
    os.environ['HOME'],"labs/11-simple_l3_mirror/solution/run_pd_rpc/setup.py"))
