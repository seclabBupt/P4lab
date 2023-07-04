simple_l3_histogram
===================

The goal of this exercise is to explore the combination of direct counters and
range matching in order to create a histogram of packet lengths.

Think of where the table that perform the counting should be placed: ingress
or egress? Why?

You can program this table in a variety of ways, using either SNMP-like ranges
that become exponentially wider: [0..64], [65..128], [129..256], etc, or you
can make them linear: [64..75], [74..85], etc...

The script pkt/send.py shows to to send packets of random length. It sends
1000 packets and records their lengths so that you can compare the program
results against them.

Try to write a nice piece of Python code to retrieve and print the histogram
instead of reading entries manually.

Additional experiments
======================

Take a look at visualizations. What kind of resources are used by the range
matching tables?

Did the required number of stages increase or stayed the same? Why?
