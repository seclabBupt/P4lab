simple_l3_rewrite
=================

The purpose of this lab is to extend simple_l3 program with a more elaborate
forwarding action that can rewrite L2 header and also update the L3 header by
decrementing the TTL.

The major emphasis is on the correct handling of IPv4 packets, specifically
the checksum (it has to be recalculated after TTL decrement) and TTL (it must
wrap around and packets with TTL 0 or 1 must not be forwarded).

Your goal is to extend the parser accordingl and add the necessary checks as
well. 

The directory contains the starter program with necessary comments.


Testing the program
===================

* Install at least one host or route entry, that uses the new action. 
* Send a packet and confirm that the TTL does get decremented and the IP
  checksum gets properly recalculated
  * The easiest way to do it is by capturing the packet in Wireshark: it is
    setup to check IPv4 checksums
  * For TTL simply compare the value in the captured packet
* Make sure that packets with TTL=0 and/or TTL=1 are not forwarded

Additional experiments
======================

Look at the visualizations of the program and notice compare the SRAM and TCAM
resources required for it with the resources required for simple_l3 program
(provided that the table sizes are the same, of course). What kind of
resources are used more ond which ones stay the same? Why?

Can you notice any other resources that got used more by this program? Why?
