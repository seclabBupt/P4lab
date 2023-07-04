/* -*- P4_16 -*- */

/*
 * This is a simple demonstration of a top-level file that simply includes
 * one of two programs that are completely compatible at the control-plane
 * level. 
 *
 * This allows us to use the same P4_NAME for both of them, greatly simplifying
 * the design of PTF tests, etc.
 *
 * There are other ways to achieve the same effect:
 *    1) You can explicitly specify P4_NAME when compiling the program
 *    2) In this particular case we could've modularized just the parser and the
 *       header structure, moving them in a separate file.
 */
#ifdef NO_VARBIT
#include "simple_l3_acl_no_varbit.p4"
#else
#include "simple_l3_acl_varbit.p4"
#endif
