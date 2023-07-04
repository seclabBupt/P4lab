simple_l3_dir_cntr
==================

The goal of this exercise is to explore the direct counter facility. You goal
is to extend one of the previous programs by adding a direct counter to it. 

Here are the options:
* Extend simple_l3.p4 or one of its derivatives by adding direct counter to
  ipv4_host table, so that you can count how many times a particular entry
  gets hit
  
* Extend simple_l3_nexthop.p4 with a direct counter that will count how many
  times a particular nexthop was used
  
* Extend simple_l3_acl.p4 program with a direct counter that will count how
  many times a particular ACL entry got hit
  
The other goal of the exercise is to be able to retrieve the counters. Given
that to do that you need to know the entry handles of the corresponding
entries in the tables, it might be a good time to learn how to do it in Python
using run_pd_rpc tools or by writing a PTF test.

In case of run_pd_rpc tool, it provides a convenient function get_entries()
that returns handles of all the entries in a given table. These handles can
then be used to retrieve the counters.

Additional experiments
======================

You can try to create a generic function that will take the names of the table
and the counter and display the counters for all entries that exist in the
table (along with the entry handles and/or match specs)

You can also extend your function to display only non-zero counters

You can also store the values of the counters, so that upon each subsequent 
invocation, the function would display only the counters that got changed
since last time they were displayed

Do not forget to take a look at the resource visualization. 

You can also experiment with the min_width attribute to see how it affects the
required amount of SRAM.
