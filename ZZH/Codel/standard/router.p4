#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "codel.p4"

#include "tcp_checksum.p4"

parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        meta.routing_metadata.tcpLength = hdr.ipv4.totalLen;
        transition select(hdr.ipv4.protocol) {
            8w17: parse_udp;
            8w6: parse_tcp;
            default: accept;
        }
    }
    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }
    state parse_udp {
        packet.extract(hdr.udp);
	    transition accept;
    }
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ethertype) {
            16w0x800: parse_ipv4;
            default: accept;
        }
    }
}

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    c_checksum() c_checksum_0;
    c_codel() c_codel_0;
    apply {
        if (standard_metadata.ingress_port == 9w1) {
	        meta.codel.queue_id = standard_metadata.egress_port;//队列ID
            c_codel_0.apply(hdr, meta, standard_metadata);
        }
        c_checksum_0.apply(hdr, meta);
    }
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action forward(bit<9> egress_spec, bit<48> dst_mac) {
        standard_metadata.egress_spec = egress_spec;
        hdr.ethernet.dst_addr = dst_mac;
    }
    table forwarding {
        actions = {
            forward;
        }
        key = {
            standard_metadata.ingress_port: exact;
            hdr.ipv4.dstAddr              : exact;
        }
    }
    apply {
        forwarding.apply();
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
