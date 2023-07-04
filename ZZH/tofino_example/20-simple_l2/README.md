simple_l2
=========

The goal of this exercise is to learn how to control a more "dynamic" P4
program in a coherent way by developing higher-level APIs

The program, defined here is a simple L2 forwarding plane that supports
VLANs and is capable of both L2 source address learning, L2 aging and VLAN
flooding of oackets with unknown L2 addresses.

It is still not a full-fledged L2 data plane program, but it is enough to
illustrate the point without obscuring it with various details, required by
the real L2 data plane.

