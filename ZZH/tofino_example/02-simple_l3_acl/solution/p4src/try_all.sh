#!/bin/bash

~/tools/p4_build.sh -DNO_VARBIT --with-suffix=.no_varbit simple_l3_acl.p4
~/tools/p4_build.sh simple_l3_acl.p4
