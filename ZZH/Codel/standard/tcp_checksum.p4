control verifyChecksum(inout headers hdr, inout metadata meta) {
    apply {
    }
}

control computeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(hdr.ipv4.isValid(), { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, 
            hdr.ipv4.totalLen, hdr.ipv4.identification, hdr.ipv4.flags, hdr.ipv4.fragOffset, 
            hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr }, 
            hdr.ipv4.hdrChecksum, HashAlgorithm.csum16);
        update_checksum_with_payload(hdr.tcp.isValid(), { hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, 
            8w0, hdr.ipv4.protocol, meta.routing_metadata.tcpLength, hdr.tcp.srcPort, hdr.tcp.dstPort, 
            hdr.tcp.seqNo, hdr.tcp.ackNo, hdr.tcp.dataOffset, hdr.tcp.res, hdr.tcp.flags, hdr.tcp.window, 
            hdr.tcp.urgentPtr}, hdr.tcp.checksum, HashAlgorithm.csum16);
    }
}

control c_checksum(inout headers hdr, inout metadata meta) {
    apply {
        meta.routing_metadata.tcpLength = meta.routing_metadata.tcpLength - 16w20;
    }
}
