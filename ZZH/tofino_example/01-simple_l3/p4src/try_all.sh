#/bin/bash

~/tools/p4_build.sh -DUSE_ALPM      --with-suffix=.alpm          simple_l3.p4
~/tools/p4_build.sh -DONE_STAGE     --with-suffix=.one_stage     simple_l3.p4
~/tools/p4_build.sh -DBYPASS_EGRESS --with-suffix=.bypass_egress simple_l3.p4
~/tools/p4_build.sh simple_l3.p4
