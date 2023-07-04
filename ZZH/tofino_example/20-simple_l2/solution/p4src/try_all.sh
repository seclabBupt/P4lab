#/bin/bash

for x in egress*p4; do  
	algo=`basename $x .p4` 
	echo $algo 
	~/tools/p4_build.sh -D`echo $algo | tr a-z A-Z` \
                            -DMANUAL_OPTIMIZATION       \
                            --with-suffix .$algo        \
                            simple_l2.p4 
done

