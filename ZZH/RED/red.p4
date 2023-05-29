#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dst_addr;
    macAddr_t src_addr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;  
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header udp_t {
    bit<16> sourcePort;
    bit<16> destPort;
    bit<16> length_;
    bit<16> checksum;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<8>  flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct metadata {
    bit<1>   mark_drop;
    bit<16>  tcpLength;
}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    tcp_t         tcp;  
    udp_t         udp;
}

error { IPHeaderTooShort }

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                  out headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
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
}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata);
    }
    
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
        if (hdr.ipv4.isValid()) {
            forwarding.apply();
        }
    }
}

register<bit<32>>(1) count_register;

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata){
    action drop() {
        mark_to_drop(standard_metadata);
    }

    action red(bit<32> min_queue, bit<32> max_queue, bit<32> max_p){
        bit<32> cha=max_queue-min_queue;
        bit<32> q=(bit<32>)standard_metadata.enq_qdepth;
        bit<32> count=0;
        count_register.read(count,0);
        int<32> panduan=(int<32>)q-(int<32>)min_queue;
        bit<32> zong=0;
        bit<32> p=0;
        if(panduan>0){
            p=max_p*(q-min_queue);
            zong=cha*10-p*count;
        }
        bit<32> rnd;
        random(rnd,0,zong);
        if(zong>0&&rnd<p){
            meta.mark_drop = 1;
            count=0;
        }
        else if(zong>0&&rnd>=p){
            count=count+1;
        }
        else{
            meta.mark_drop = 0; 
        }
        count_register.write(0,count);
        if(q>max_queue){
            meta.mark_drop = 1; 
        }
    }

    table aqm{
        key = {
            standard_metadata.egress_port: exact;
        }    
        actions = {
            red();
            NoAction;
        }
        default_action = NoAction; 
    }


    apply {
        meta.tcpLength = hdr.ipv4.totalLen;
        meta.tcpLength = meta.tcpLength-20;
        aqm.apply();    
        if (meta.mark_drop == 1) {
            drop();
        } 
    }

}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
            hdr.ipv4.isValid(), 
            { hdr.ipv4.version, 
            hdr.ipv4.ihl, 
            hdr.ipv4.diffserv, 
            hdr.ipv4.totalLen, 
            hdr.ipv4.identification, 
            hdr.ipv4.flags, 
            hdr.ipv4.fragOffset, 
            hdr.ipv4.ttl, 
            hdr.ipv4.protocol, 
            hdr.ipv4.srcAddr, 
            hdr.ipv4.dstAddr }, 
            hdr.ipv4.hdrChecksum, 
            HashAlgorithm.csum16);
        update_checksum_with_payload(
            hdr.tcp.isValid(), 
            { hdr.ipv4.srcAddr, 
            hdr.ipv4.dstAddr, 
            8w0, 
            hdr.ipv4.protocol, 
            meta.tcpLength, 
            hdr.tcp.srcPort, 
            hdr.tcp.dstPort, 
            hdr.tcp.seqNo, 
            hdr.tcp.ackNo, 
            hdr.tcp.dataOffset, 
            hdr.tcp.res, 
            hdr.tcp.flags, 
            hdr.tcp.window, 
            hdr.tcp.urgentPtr}, 
            hdr.tcp.checksum, 
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
