/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

const bit<8> TYPE_TCP = 6;
const bit<8> TYPE_UDP = 17;

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header cpu_header_t {
    bit<8>    flag;
}

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
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

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> udplen;
    bit<16> udpchk;
}

struct custom_metadata_t {
    bit<32> hash_val1;
    bit<32> hash_val2;
    bit<32> hash_val3;
    bit<32> hash_val4;
    bit<32> hash_val5;
    bit<32> hash_val6;
    bit<32> hash_val7;
    bit<32> hash_val8;
    bit<32> hash_val9;
    bit<32> hash_val10;

    bit<32> count_val1;
    bit<32> count_val2;
    bit<32> count_val3;
    bit<32> count_val4;
    bit<32> count_val5;
    bit<32> count_val6;
    bit<32> count_val7;
    bit<32> count_val8;
    bit<32> count_val9;
    bit<32> count_val10;

    bit<32> count_min;
    bit<32> count_tot;
    bit<32> sample_threshold;
    bit<16> index;
    bit<32> hh_threshold;
    bit<32> count_max;
    bit<32> count_max_final;
    bit<32> sample_hash_value;
    bit<32> current_count;
    bit<32> sum;
}

struct heavy_hitter_t {
    bit<32> srcAddr;
    bit<32> dstAddr;
    bit<32> count;
}

enum bit<8> FieldLists {
    none = 0,
    redirect_FL = 1
}

struct metadata {
    @field_list(FieldLists.redirect_FL)
    custom_metadata_t custom_metadata;
    heavy_hitter_t heavy_hitter;
    bit<16>  tcpLength;
    bit<1>   mark_drop;
    bit<1>   mark_exist;
    bit<32>  port_sum;
}

struct headers {
    cpu_header_t cpu_header;
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    tcp_t        tcp;
    udp_t        udp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {

        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType){

            TYPE_IPV4: ipv4;
            default: accept;
        }
    }

    state ipv4 {
        packet.extract(hdr.ipv4);

        transition select(hdr.ipv4.protocol){
            TYPE_UDP: udp;
            TYPE_TCP: tcp;
            default: accept;
        }
    }

    state tcp {
       packet.extract(hdr.tcp);
       transition accept;
    }

    state udp {
       packet.extract(hdr.udp);
       transition accept;
    }

}

#define CPU_MIRROR_SESSION_ID 250
#define MIN 1
#define SKETCH_CELL_BIT_WIDTH 32
#define CM_ROW 30
#define THETA 5
#define EPSILON_INVERSE 10000
#define K 10
#define W 3
#define SAMPLELIST_SIZE 30
#define MAXIMUM_PACKETS 10000

#define SKETCH_REGISTER(num) register<bit<SKETCH_CELL_BIT_WIDTH>>(CM_ROW) sketch##num
#define SKETCH_COUNT(num, algorithm) hash(meta.custom_metadata.hash_val##num, HashAlgorithm.algorithm, (bit<16>)0, {hdr.ipv4.srcAddr, \
 hdr.ipv4.dstAddr}, (bit<32>)CM_ROW);\
 sketch##num.read(meta.custom_metadata.count_val##num, meta.custom_metadata.hash_val##num); \
 meta.custom_metadata.count_val##num = meta.custom_metadata.count_val##num +1; \
 sketch##num.write(meta.custom_metadata.hash_val##num, meta.custom_metadata.count_val##num)

SKETCH_REGISTER(1);
SKETCH_REGISTER(2);
SKETCH_REGISTER(3);
SKETCH_REGISTER(4);
SKETCH_REGISTER(5);
SKETCH_REGISTER(6);
SKETCH_REGISTER(7);
SKETCH_REGISTER(8);
SKETCH_REGISTER(9);
SKETCH_REGISTER(10);

register<bit<32>>(1) packet_tot;
register<bit<32>>(SAMPLELIST_SIZE) sampleList_src;
register<bit<32>>(SAMPLELIST_SIZE) sampleList_dst;
register<bit<32>>(SAMPLELIST_SIZE) sampleList_count;
register<bit<32>>(3) hh_r;    //0: srcAddr, 1: dstAddr, 2: count
register<bit<32>>(64) port_packet;
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

    action set_heavy_hitter_count() {
        SKETCH_COUNT(1, crc32_custom);
        SKETCH_COUNT(2, crc32_custom);
        SKETCH_COUNT(3, crc32_custom);
        SKETCH_COUNT(4, crc32_custom);
        SKETCH_COUNT(5, crc32_custom);
        SKETCH_COUNT(6, crc32_custom);
        SKETCH_COUNT(7, crc32_custom);
        SKETCH_COUNT(8, crc32_custom);
        SKETCH_COUNT(9, crc32_custom);
        SKETCH_COUNT(10, crc32_custom);
    }

    action do_copy_to_cpu() {
        clone_preserving_field_list(CloneType.I2E, CPU_MIRROR_SESSION_ID, FieldLists.redirect_FL);
    }

    action increment_tot() {
        packet_tot.read(meta.custom_metadata.count_tot,0);
        meta.custom_metadata.count_tot=meta.custom_metadata.count_tot+1;
        packet_tot.write(0,meta.custom_metadata.count_tot);
    }

    action do_read_tot() {
        packet_tot.read(meta.custom_metadata.sum,0);
    }

    action do_find_min1() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val1;
    }

    action do_find_min2() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val2;
    }

    action do_find_min3() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val3;
    }

    action do_find_min4() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val4;
    }

    action do_find_min5() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val5;
    }

    action do_find_min6() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val6;
    }

    action do_find_min7() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val7;
    }

    action do_find_min8() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val8;
    }

    action do_find_min9() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val9;
    }

    action do_find_min10() {
        meta.custom_metadata.count_min=meta.custom_metadata.count_val10;
    }

    action do_set_maxinum() {
        meta.heavy_hitter.srcAddr=hdr.ipv4.srcAddr;
        meta.heavy_hitter.dstAddr=hdr.ipv4.dstAddr;
        meta.heavy_hitter.count=meta.custom_metadata.count_min;
        hh_r.write(0,meta.heavy_hitter.srcAddr);
        hh_r.write(1,meta.heavy_hitter.dstAddr);
        hh_r.write(2,meta.heavy_hitter.count);
    }

    action do_read_packets() {
        packet_tot.read(meta.custom_metadata.count_tot,0);
        meta.custom_metadata.sample_threshold=meta.custom_metadata.count_tot*(W/THETA + 1/EPSILON_INVERSE)/K;
    }

    action forward(bit<9> egress_spec, bit<48> dst_mac) {
        standard_metadata.egress_spec = egress_spec;
        hdr.ethernet.dstAddr = dst_mac;
    }

    action do_read_max_count() {
        hh_r.read(meta.custom_metadata.count_max,2);
    }

    action do_check_sampleList() {
        hash(meta.custom_metadata.sample_hash_value,HashAlgorithm.crc32,(bit<16>)0,{hdr.ipv4.srcAddr,hdr.ipv4.dstAddr},(bit<32>)SAMPLELIST_SIZE);
        sampleList_count.read(meta.custom_metadata.current_count, meta.custom_metadata.sample_hash_value);
    }

    action do_add_sampleList() {
        sampleList_src.write(meta.custom_metadata.sample_hash_value,hdr.ipv4.srcAddr);
        sampleList_dst.write(meta.custom_metadata.sample_hash_value,hdr.ipv4.dstAddr);
        sampleList_count.write(meta.custom_metadata.sample_hash_value, meta.custom_metadata.count_min);
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
        increment_tot();
        do_read_tot();
        if(meta.custom_metadata.sum >= MAXIMUM_PACKETS){
            do_copy_to_cpu();
        }
        forwarding.apply();
        set_heavy_hitter_count();
        do_find_min1();
        if(meta.custom_metadata.count_min > meta.custom_metadata.count_val2){
                do_find_min2();
        }
        if(meta.custom_metadata.count_min > meta.custom_metadata.count_val3){
                do_find_min3();
        }
        if(meta.custom_metadata.count_min > meta.custom_metadata.count_val4){
                do_find_min4();
        }
        if(meta.custom_metadata.count_min > meta.custom_metadata.count_val5){
                do_find_min5();
        }
        if(meta.custom_metadata.count_min > meta.custom_metadata.count_val6){
                do_find_min6();
        }
        if(meta.custom_metadata.count_min > meta.custom_metadata.count_val7){
                do_find_min7();
        }
        if(meta.custom_metadata.count_min > meta.custom_metadata.count_val8){
                do_find_min8();
        }
        if(meta.custom_metadata.count_min > meta.custom_metadata.count_val9){
                do_find_min9();
        }
        if(meta.custom_metadata.count_min > meta.custom_metadata.count_val10){
                do_find_min10();
        }
        do_read_packets();
        if(meta.custom_metadata.count_min > MIN&&meta.custom_metadata.count_min > meta.custom_metadata.sample_threshold){
            do_check_sampleList();
            if(meta.custom_metadata.current_count < meta.custom_metadata.count_min){
                do_add_sampleList();
                do_read_max_count();
                if(meta.custom_metadata.count_min > meta.custom_metadata.count_max){
                    do_set_maxinum();
                }
            }
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    action port_packet_count(){
        port_packet.read(meta.port_sum,(bit<32>)standard_metadata.egress_port);
        meta.port_sum=meta.port_sum+1;
        port_packet.write((bit<32>)standard_metadata.egress_port,meta.port_sum);
    }

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action h_drop(bit<32> C,bit<32> k){
        if(10*((bit<32>)standard_metadata.deq_qdepth)>k*C){
            meta.mark_drop = 1;
        }
    }

    action go_to_drop(bit<32> C,bit<32> k) {
        port_packet.read(meta.port_sum,(bit<32>)standard_metadata.egress_port);
        if(10*((bit<32>)standard_metadata.deq_qdepth)>k*C&&(10-k)*C*meta.custom_metadata.count_min>meta.port_sum*(C-(bit<32>)standard_metadata.deq_qdepth)){
            meta.mark_drop = 1;
        }
    }

    action heavy_exist(){
        meta.mark_exist=1;
    }
    
    table aqm{
        key = {
            standard_metadata.egress_port: exact;
        }    
        actions = {
            go_to_drop();
            NoAction;
        }
        default_action = NoAction; 
    }

    table exist{
        key={
            standard_metadata.egress_port: exact;
        }
        actions={
            heavy_exist();
        } 
    }

    table heavy_drop{
        key={
            hdr.ipv4.srcAddr:exact;
            hdr.ipv4.dstAddr:exact;
            standard_metadata.egress_port: exact;
        }
        actions={
            h_drop();
        }
    }

    apply {
        meta.tcpLength = hdr.ipv4.totalLen;
        meta.tcpLength = meta.tcpLength-20;
        port_packet_count();
        if(meta.port_sum<=1000&&exist.apply().hit){
            heavy_drop.apply();
        }
        else{
            aqm.apply();
        }
        if (meta.mark_drop == 1) {
            drop();
        }
        if(standard_metadata.instance_type == 0x01) {
            hdr.cpu_header.setValid();
            hdr.cpu_header.flag=1;
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
        packet.emit(hdr.cpu_header);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
