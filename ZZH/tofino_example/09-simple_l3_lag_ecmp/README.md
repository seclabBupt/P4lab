simple_l3_lag_ecmp
==================

The goal of this exercises is learning how to implement LAG or ECMP using
action profiles with dynamic selection. 

We will do it by enhancing the program simple_l3_nexthop.p4 with the ability
to associate multiple actions (actually multiple sets of action data) with a
given nexthop ID, coupled with the ability to choose one action from such a
group using an action selector. 

Your task is:

1. To convert the nexthop table from a regular match-action table into a table
   that uses action_profile with a dynamic action_delector

2. To add the code that will calculate a hash, based on some fields of your
   choice that you believe can separate flows reasonably
   
3. (Optionally) since the program template is already written to process both
   IPv4 and IPv6 packets, you can provide separate hash calculations for these
   protocols and a way to choose the result, based on the corresponding header
   validity
   
4. Send in packets that represent a variety of flows and observe the packet
   distribution in action
   
Testing tips
============

Manual Testing
--------------
1. To observe the counts on various ports, the easiest way is to check packet
   counters. You can do it using `pm show` command of the ucli:

``` 
bfshell> ucli

bf-sde> pm

bf-sde.pm> show 1/-
-----+----+---+----+------+----+---+---+---+--------+------------+------------+-
PORT |MAC |D_P|P/PT|SPEED |FEC |RDY|ADM|OPR|LPBK    |FRAMES RX   |FRAMES TX   |E
-----+----+---+----+------+----+---+---+---+--------+------------+------------+-
1/0  |15/0|  0|0/ 0| 10G  |NONE|YES|DIS|DWN|  NONE  |          30|           0| 
1/1  |15/1|  1|0/ 1| 10G  |NONE|YES|DIS|DWN|  NONE  |           0|          10| 
1/2  |15/2|  2|0/ 2| 10G  |NONE|YES|DIS|DWN|  NONE  |           0|          15| 
1/3  |15/3|  3|0/ 3| 10G  |NONE|YES|DIS|DWN|  NONE  |           0|           5| 
```

2. The `send.py` script accepts two parameters: the destination IP address and
   the number of packets to send. These will be UDP packets, sent with the
   random Source IP addresses and random source and destination ports.

3. The solutions directory contains a sample `setup.py` script for bfrt-python

Automated testing
-----------------

The solution directory contains a sample PTF test. The key to that PTF test is
the ability of the function verify_packet_any_port() to return the port the
packet was received on. For example:

``` python
    (port_idx, result) = verify_packet_any_port(self, pkt, [1, 3, 5, 6])
```

If packet is received on one of the specified ports, port_idx will be set to
the *index* of the port in the port list that was passed to the function. For
example, if the packet was received on port 5, port_idx will be set to 2.

Additional experiments
======================

Explore other APIs that are available for action profiles. You can
enable/disable members dynamically, and even verify that only the traffic from
the disabled  members gets redistributed.

Look at visualizations and notice the additional resources used by this
program.

P4 Programming Exercise
=======================

You can easily implement non-standard methods of traffic distribution. For
example, can you modify the program to distribute each packet to a random
LAG/ECMP member? 

Hint: Use `Random()` extern, that is available in TNA. It can return random
values of type bit<w>. You can see $SDE_INSTALL/share/p4c/p4include/tofino.p4
for details, but here are the basics:

Instantiate:
``` 
Random<bit<14>>() my_rng; /* Produces random nubers between 0 and 2^14-1 */
```

Use:

```
hash = my_rng.get()
```

Try to run the same PTF test and see if the fairness of the distribution is
better.

A more challenging exercise might be to implement round-robin
distribution. That will require the use of registers, though, which is really
BA-201 material.

PTF Exercise
============

Create and test a configuration with a weighted distribution. To do so, create
multiple members that point to the same port/ECMP path and add them to the
group. You will need to change the code that verifies the distribution to
allow for weighted (proportional) distribution. One way to do it is to have a
separate list with the weights for each member (default is [1, 1, 1])
