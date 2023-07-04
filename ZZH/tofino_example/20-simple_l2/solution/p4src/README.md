Egress pipeline implementations
===============================

This program has modularized code for egress pipeline and provides six
different implementations. The reason for these is to allow you to try 
different ones and check out the differences in terms of resources used.

 * egress_single_table.p4 (-DEGRESS_SINGLE_TABLE)
   This implementation uses a single table that matches on the packet using
   the VLAN ID and the lower 7 bits of egress port number. This is the most 
   "naive" implementation that uses a lot of resources
   
 * egress_table_and_if (-DEGRESS_TABLE_AND_IF) uses a table that matches
   on the packet using the VLAN ID and the lower 7 bits of egress port number
   to derive two boolean metadata variables and then a nested if() statement
   to resolve the action
   
 * egress_table_and_switch (-DEGRESS_TABLE_AND_SWITCH) uses a table that matches
   on the packet using the VLAN ID and the lower 7 bits of egress port number
   to derive one of 3 actions and then uses the switch statement to resolve
   them. Essentially, we encode everything in the match entry overhead
   
 * egress_table_and_table (-DEGRESS_TABLE_AND_TABLE) uses a table to
   resolve the actions, rather than switch() or nested if() statements
   
 * egress_registers_and_if (-DEGRESS_REGISTERS_AND_IF) is similar to 
   egress_table_and_if, but uses a pair of registers, each indexed by 
   the VLAN ID and the lower 7 bits of egress port number. After that the 
   action is ressolved using a nexted if() statement. Note, that thee current
   version of the compiler does not produce optimal code for this unless manual
   optimization (-DMANUAL_OPTIMIZATION) is used.
   
 * egress_registers_and_table (-DEGRESS_REGISTERS_AND_TABLE) also uses a 
   pair of registers, but resolves the action using a single table rather 
   than nested if() statements, similar to egress_table_and_table
   
You can use the script `try_all.sh` to compile all variants and then use
p4i tool to compare them.

