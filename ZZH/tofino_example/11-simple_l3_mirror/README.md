simple_l3_mirror
================

The purpose if this exercise is to learn how to use mirroring
functionality of the device for the purposes of either mirroring the packets
(e.g. for the remote observation) or copying the packets to the CPU.

Use the example, provided in the presentation or in the solution/ directory to
see how a mirror session can be programmed

P4 Programming Exercise
=======================

The solution code does not cover the egress mirroring. You can extend the
offered program by adding egress mirroring (using clone_e2e) (primitive). Once
this is done, you should be able to create mirrors of the mirrored packets. 
