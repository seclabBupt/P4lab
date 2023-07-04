simple_l3_ind_cntr
==================

The goal of this exercise is to explore the indirect counter facility. You goal
is to extend simple_l3.p4 program (or one of its derivatives) by adding
indirect counters that can be shared between various entries in ipv4_host and
ipv4_route tables.

The goal is to be able to count packets on a per-destination subnet basis. For
example, if you have entries for 192.168.1.1, 192.168.1.2, 192.168.1.10 in
ipv4_host and an entry for 192.168.1.0/24 in ipv4_route table, then if you
want to count all the packets destined to 192.168.1.0/24, all these 4 entries
should be producing the same counter index.

Additional experiments
======================

Look at visualizatinos for this program and compare them with
simple_l3_dir_cntr.p4 What is the main difference?

Try in increase the number of counters. What are the limits? What needs to be
done if you want to go beyond those limits? 
