from ipaddress import ip_address

p4 = bfrt.simple_l3_ind_cntr.pipe

ipv4_host = p4.Ingress.ipv4_host
ipv4_host.add_with_send(dst_addr=ip_address('192.168.1.1'),
                        port=1, stats_idx=1)
ipv4_host.add_with_send(dst_addr=ip_address('192.168.1.2'),
                        port=2, stats_idx=1)
ipv4_host.add_with_drop(dst_addr=ip_address('192.168.1.3'),
                        stats_idx=1)
ipv4_host.add_with_send(dst_addr=ip_address('192.168.1.254'),
                        port=64, stats_idx=1)

ipv4_lpm =  p4.Ingress.ipv4_lpm
ipv4_lpm.add_with_send(
    dst_addr=ip_address('192.168.1.0'), dst_addr_p_length=24,
    port=1, stats_idx=1)
ipv4_lpm.add_with_drop(
    dst_addr=ip_address('192.168.0.0'), dst_addr_p_length=16,
    stats_idx=2)
ipv4_lpm.add_with_send(
    dst_addr=ip_address('0.0.0.0'),     dst_addr_p_length=0,
    port=64, stats_idx=3)

                       
