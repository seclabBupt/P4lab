from ipaddress import ip_address

p4 = bfrt.simple_l3_acl.pipe

# This function can clear all the tables and later on other fixed objects
# once bfrt support is added.
def clear_all(verbose=True, batching=True):
    global p4
    global bfrt
    
    def _clear(table, verbose=False, batching=False):
        if verbose:
            print("Clearing table {:<40} ... ".
                  format(table['full_name']), end='', flush=True)
        try:    
            entries = table['node'].get(regex=True, print_ents=False)
            try:
                if batching:
                    bfrt.batch_begin()
                for entry in entries:
                    entry.remove()
            except Exception as e:
                print("Problem clearing table {}: {}".format(
                    table['name'], e.sts))
            finally:
                if batching:
                    bfrt.batch_end()
        except Exception as e:
            if e.sts == 6:
                if verbose:
                    print('(Empty) ', end='')
        finally:
            if verbose:
                print('Done')

        # Optionally reset the default action, but not all tables
        # have that
        try:
            table['node'].reset_default()
        except:
            pass
    
    # The order is important. We do want to clear from the top, i.e.
    # delete objects that use other objects, e.g. table entries use
    # selector groups and selector groups use action profile members
    

    # Clear Match Tables
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR']:
            _clear(table, verbose=verbose, batching=batching)

    # Clear Selectors
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['SELECTOR']:
            _clear(table, verbose=verbose, batching=batching)
            
    # Clear Action Profiles
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['ACTION_PROFILE']:
            _clear(table, verbose=verbose, batching=batching)
    
clear_all()

p4.Ingress.ipv4_host.add_with_send(
    dst_addr=ip_address("192.168.1.1"), port=1)
p4.Ingress.ipv4_lpm.add_with_send(
    dst_addr=ip_address("192.168.1.0"), dst_addr_p_length=24,  port=64)

# ipv4_acl

# A compact way: Deny all UDP packets with sport==7
p4.Ingress.ipv4_acl.add_with_drop(
    src_addr=ip_address('0.0.0.0'), src_addr_mask=ip_address('0.0.0.0'),
    dst_addr=ip_address('0.0.0.0'), dst_addr_mask=ip_address('0.0.0.0'),
    protocol=17,  protocol_mask=0xFF,
    word_1=7,     word_1_mask=0xFFFF,
    word_2=0,     word_2_mask=0,
    first_frag=1, first_frag_mask=1,
    match_priority=10)

# A more elaborate way. Deny all packets with Protocol == 132 and sport == 7
p4.Ingress.ipv4_acl.add_with_drop(
    src_addr=ip_address('0.0.0.0'), src_addr_mask=ip_address('0.0.0.0'),
    dst_addr=ip_address('0.0.0.0'), dst_addr_mask=ip_address('0.0.0.0'),
    protocol=132, protocol_mask=0xFF,
    word_1=7, word_1_mask=0xFFFF,
    word_2=7, word_2_mask=0xFFFF,
    first_frag=1,  first_frag_mask=1,
    match_priority=5)

# Deny all packets with DST IP 192.168.1.25
p4.Ingress.ipv4_acl.add_with_drop(
    src_addr=ip_address('0.0.0.0'), src_addr_mask=ip_address('0.0.0.0'),
    dst_addr=ip_address('192.168.1.25'),
    dst_addr_mask=ip_address('255.255.255.255'),
    protocol=0, protocol_mask=0,
    word_1=0, word_1_mask=0,
    word_2=0, word_2_mask=0,
    first_frag=0,  first_frag_mask=0,
    match_priority=20)

bfrt.complete_operations()

# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")
print ("\nTable ipv4_host:")
p4.Ingress.ipv4_host.dump(table=True)
print ("\nTable ipv4_lpm:")
p4.Ingress.ipv4_lpm.dump(table=True)
print ("\nTable ipv4_acl:")
p4.Ingress.ipv4_acl.dump(table=True)
