simple_l3_nexthop
================

The purpose of this lab is to modify simple_l3_rewrite program to reduce its
action SRAM requirements by allowing multiple host/route entries to share the
same nexthop information.

The directory contains the starter program with necessary comments.

Testing the program
===================

Since the functionality of this program is the same as the functionality of
simple_l3_rewrite, basic testing is quite similar.

* Install at least one host or route entry, that uses the new action. 
* Send a packet and confirm that the TTL does get decremented and the IP
  checksum gets properly recalculated
  * The easiest way to do it is by capturing the packet in Wireshark: it is
    setup to check IPv4 checksums
  * For TTL simply compare the value in the captured packet
* Make sure that packets with TTL=0 and/or TTL=1 are not forwarded

More P4 programming
===================

You can also go further. For example, the number of different values for the
"new source MAC address" is usually very small. Thus, instead of using 48 bits
per entry to store it, you can create a separate table and use a relatively
small (8 bit) index into it.

Additional experiments
======================

You can also create multiple host/route entries that point to the same
nexthop. 
* Send the packet and make sure the nexthop is used and the packet is
  forwarded as expected.
* Modify the nexthop. Observe, that the change did affect all the routes (by
  sending packets to the other netries that use the same nexthop)

Look at the visualizations of the program and notice compare the SRAM and TCAM
resources required for it with the resources required for simple_l3_rewrite
program (provided that the table sizes are the same, of course). What is the
most important "price" we are paying for this solution? Why?
