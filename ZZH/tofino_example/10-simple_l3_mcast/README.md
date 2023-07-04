simple_l3_mcast
===============

The purpose of this exercise is to learn how to use PRE (Packet Replication
Engine). The standard workflow consists of the following:

1. The ingress control determines the multicast group ID(s) used for the
   packet. In this exercise we suggest that you amend tables ipv4_host and
   ipv4_lpm with another action that will send a packet to a multicast group
   (`ig_intr_md_for_tm.mcast_grp_a`).
   
2. The PRE (mutlicast engine) is programmed using dedicated ("fixed")
   multicast (mc) APIs. At the very minimum you need to create a group with
   an ID, create a multicast node (for a set of ports) and associate this node
   with the multicast group
   
3. All replicated packet copies will pass through the egress control that will
   have a chance to modify each copy independently from others. To
   distringuish between individual copies you can use the following intrinsic
   metadata fields:
   * `eg_intr_md.egress_rid` -- comes from the RID, associated with the given
     multicast node
   * `eg_intr_md.egress_port` -- indicates which port the packet is destined
     to. Depending on the port bitmap, associated with the node, egress
     pipeline can see multiple packets with the same egress_rid, but different
     egress_port
   * `eg_intr_md.egress_rid_first` -- this bit indicates that the given packet
     is the **first** one in the given replication. It is very useful if you
     need to count events on per-group, rather than per-replication basis
   1. We suggest you add a table in the egress control to  match the packet on
      at least some of these fields and perform different packet
      modifications, based on the values in these fields.
     
 4. After everything is configured, you can send a packet and observe it being
    replicated and modified.
    
Additional recommendations
==========================

The port numbering scheme inside Tofino PRE differs from the port numbering
scheme in the Match-Action Pipeline. The former uses the formula 72*pipe+port,
where the latter uis using 128*pipe+port. 

run_pd_rpc.py tool offers conversion functions, such as devport_to_mcport() to
convert from one numbering scheme to another. Also, it offers
devports_to_mcbitmap that converts a list of devports into a bitmap, suitable
for MC node creation.

The multicast APIs use `mc_sess`, rather than `sess_hdl`. However, this 
parameter is optional (as is sess_hdl for the rest of the APIs). The tool
opens a session and sets the varialble automatically
your experiments.

Additional Exercises
====================

P4 Programming
--------------
Note that the multicasted packets do not have correct IPv4 and UDP
checksum. Why is this happenning? Add the code to the P4 program that will fix
this issue

PD (Fixed) Programming
----------------------
Create a LAG in the PRE (the APIs under mc. should be self-explanatory) and
observe the LAG replication? Will there be any additional changes that you
need to put into the P4 program? What are those?
