#include <core.p4>
#include <v1model.p4>

#define WRITE_REG(r, v) r.write((bit<32>)standard_metadata.egress_port, v);
#define READ_REG(r, v) r.read(v,(bit<32>)standard_metadata.egress_port);
#define CAP(c, v, a, t){ if (v > c) a = c; else a = (t)v; }

const bit<16> TYPE_IPV4 = 0x800;
const bit<32> MAX_RND = 0xFFFFFFFF;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;
//input parameters
typedef int<32> alpha_t;
typedef int<32> beta_t;
typedef int<32> delay_t;
typedef bit<5> interval_t;
//state registers
register<bit<48>>(256) r_update_time;  // timestamp of previous PI calculation
register<int<32>>(256) r_queue_delay;  // queue delay at previous PI calculation
register<bit<32>>(256) r_probability;  // probability at previous PI calculation

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

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata){
    action drop() {
        mark_to_drop(standard_metadata);
    }

    // alpha and beta needs to be multiplied by (2^32-1)/1000000 = 4295 which is due to random value goes to 2^32
    // alpha = 0,3125 => 1342 and beta = 3,125 => 13422
    // delay target is in us = 20000 => 20 msec
    // PI update interval is 2^x us, x = 15 => 32768 us ~= 33 msec
    action pi2(alpha_t alpha, beta_t beta, delay_t target, interval_t interval){
        bit<48> last_update_time = 0;
        int<32> last_queue_delay;
        bit<32> last_probability;
    
        READ_REG(r_update_time, last_update_time);  // read r_update_time -> timestamp of last prob update
        READ_REG(r_queue_delay, last_queue_delay);  // read q_delay during previous update time
        READ_REG(r_probability, last_probability);  // read last calculated PI probability 
  
        // initialization - no previous update time
        if (last_update_time == 0) {
            last_update_time = standard_metadata.egress_global_timestamp;
        }
        //find how many time laps - divide by 2^interval = 32768
        bit<32> update_laps = (bit<32>) ((standard_metadata.egress_global_timestamp - last_update_time) >> interval); 

        if (update_laps >= 1){
            if (update_laps >= 2000) update_laps = 2000;   // limit to max useful number = max queue_del / min target (1ms)

            int<32> prev_queue_delay = last_queue_delay;   // preserve previous queue delay
            CAP(1000000, standard_metadata.deq_timedelta, last_queue_delay, int<32>); // update and cap queueing delay to 1s

            // calculate change in probability;  subtract extra alpha.TARGET for every extra lap Q assumed 0
            int<32> delta = (last_queue_delay - (int<32>)update_laps * target) * alpha + (last_queue_delay - prev_queue_delay) * beta;
            bit<33> new_probability = (bit<33>) last_probability; // add one bit to detect under- and overflows
            new_probability = (bit<33>) ((int<33>) new_probability + (int<33>) delta);  // delta needs sign preservation
            if (new_probability > (bit<33>)MAX_RND) { // check for under- and overflows
                if (delta > 0) last_probability = MAX_RND;
                else last_probability = 0;
            } else last_probability = (bit<32>) new_probability; // otherwise update latest probability

            last_update_time = standard_metadata.egress_global_timestamp; // set last_update_time
        }

        //update registers
        WRITE_REG(r_probability, last_probability); // store new drop probability
        WRITE_REG(r_queue_delay, last_queue_delay); // store delay	
        WRITE_REG(r_update_time, last_update_time); // store last_update_time

        bit<32> rnd;
        random(rnd,0,MAX_RND);
        if ((rnd < last_probability) && ((rnd << 16) < last_probability)) // squaring by using 16 lsb as second independent random value
            meta.mark_drop = 1; 

    }
    

    table aqm{
        key = {
            standard_metadata.egress_port: exact;
        }    
        actions = {
            pi2();
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
