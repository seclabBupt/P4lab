/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/* CONSTANTS */

const bit<16> TYPE_IPV4 = 0x800;
const bit<8>  TYPE_INFORM  = 251;
const bit<8>  TYPE_REQUEST = 252;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    tos;
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

header cluster_t{
    bit<32> clusterCPU;
    bit<32> clusterMEM;
    bit<32> clusterDISK;
    bit<32> clusterNET;

}

header user_t{
    bit<32> userCPU;
    bit<32> userMEM;
    bit<32> userDISK;
    bit<32> userNET;
}

header dstip_t{
    ip4Addr_t dstIP;
}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    cluster_t    cluster;
    user_t       user;
    dstip_t      dstip;
}

struct metadata {
    bit<32> clusterCPU1;
    bit<32> clusterCPU2;
    bit<32> clusterCPU3;

    bit<32> clusterMEM1;
    bit<32> clusterMEM2;
    bit<32> clusterMEM3;

    bit<32> clusterDISK1;
    bit<32> clusterDISK2;
    bit<32> clusterDISK3;

    bit<32> clusterNET1;
    bit<32> clusterNET2;
    bit<32> clusterNET3;

    int<32> cpucha;
    int<32> memcha;
    int<32> diskcha; 
    int<32> netcha;
    int<32> cpuratio;
    int<32> memratio;
    int<32> diskratio;
    int<32> netratio;
    int<32> leastscore1;
    int<32> leastscore2;
    int<32> leastscore3;

    int<32> cpu_balance;
    int<32> mem_balance;
    int<32> disk_balance;
    int<32> net_balance;
    int<32> cpu_membalance;
    int<32> cpu_diskbalance;
    int<32> cpu_netbalance;
    int<32> mem_diskbalance;
    int<32> mem_netbalance;
    int<32> disk_netbalance;

    int<32> balancescore1;
    int<32> balancescore2;
    int<32> balancescore3;

    bit<32> delayratio;
    int<32> netscore1;
    int<32> netscore2;
    int<32> netscore3;

    int<32> cluster1_score;
    int<32> cluster2_score;
    int<32> cluster3_score;
    int<32> maxscore;
    bit<32> destinationIP;
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
            TYPE_INFORM: cluster;
            TYPE_REQUEST: user;
            default: accept;
        }
    }

    state cluster {
       packet.extract(hdr.cluster);
       transition accept;
    }

    state user {
       packet.extract(hdr.user);
       transition accept;
    }
}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

#define P 4
#define Q 6
#define N 1000
#define REGISTER_LENGTH 6
#define CLUSTER_REGISTER(num) register<bit<32>>(REGISTER_LENGTH) cluster_ID##num
#define CLUSTER_WRITECHANGE(num) cluster_ID##num.write(0,hdr.ipv4.srcAddr); \
 cluster_ID##num.write(1,hdr.cluster.clusterCPU); \
 cluster_ID##num.write(2,hdr.cluster.clusterMEM); \
 cluster_ID##num.write(3,hdr.cluster.clusterDISK); \
 cluster_ID##num.write(4,hdr.cluster.clusterNET)

#define CLUSTER_SCORE(num) cluster_ID##num.read(meta.clusterCPU##num,1); \
 cluster_ID##num.read(meta.clusterMEM##num,2); \
 cluster_ID##num.read(meta.clusterDISK##num,3); \
 cluster_ID##num.read(meta.clusterNET##num,4); \
 meta.cpucha=(int<32>)meta.clusterCPU##num-(int<32>)hdr.user.userCPU; \
 meta.memcha=(int<32>)meta.clusterMEM##num-(int<32>)hdr.user.userMEM; \
 meta.diskcha=(int<32>)meta.clusterDISK##num-(int<32>)hdr.user.userDISK; \
 meta.netcha=(int<32>)meta.clusterNET##num-(int<32>)hdr.user.userNET; \
 if(meta.cpucha<0||meta.memcha<0||meta.diskcha<0||meta.netcha<0){ \
     meta.leastscore##num=0; \
     meta.balancescore##num=0; \
 } \
 else{ \
     meta.cpuratio=meta.cpucha*(10000/N); \
     meta.memratio=meta.memcha*(10000/N); \
     meta.diskratio=meta.diskcha*(10000/N); \
     meta.netratio=meta.netcha*(10000/N); \
     meta.leastscore##num=meta.cpuratio+meta.memratio+meta.diskratio+meta.netratio; \
     meta.leastscore##num=meta.leastscore##num*Q; \
     meta.cpu_balance=(N-meta.cpucha)*(10000/N); \
     meta.mem_balance=(N-meta.memcha)*(10000/N); \
     meta.disk_balance=(N-meta.diskcha)*(10000/N); \
     meta.net_balance=(N-meta.netcha)*(10000/N); \
     meta.cpu_membalance=meta.cpu_balance-meta.mem_balance; \
     if(meta.cpu_membalance<0){ \
         meta.cpu_membalance=0-meta.cpu_membalance; \
     } \
     meta.cpu_diskbalance=meta.cpu_balance-meta.disk_balance; \
     if(meta.cpu_diskbalance<0){ \
         meta.cpu_diskbalance=0-meta.cpu_diskbalance; \
     } \
     meta.cpu_netbalance=meta.cpu_balance-meta.net_balance; \
     if(meta.cpu_netbalance<0){ \
         meta.cpu_netbalance=0-meta.cpu_netbalance; \
     } \
     meta.mem_diskbalance=meta.mem_balance-meta.disk_balance; \
     if(meta.mem_diskbalance<0){ \
         meta.mem_diskbalance=0-meta.mem_diskbalance; \
     } \
     meta.mem_netbalance=meta.mem_balance-meta.net_balance; \
     if(meta.mem_netbalance<0){ \
         meta.mem_netbalance=0-meta.mem_netbalance; \
     } \
     meta.disk_netbalance=meta.disk_balance-meta.net_balance; \
     if(meta.disk_netbalance<0){ \
         meta.disk_netbalance=0-meta.disk_netbalance; \
     } \
     meta.balancescore##num=meta.cpu_membalance+meta.cpu_diskbalance+meta.cpu_netbalance+meta.mem_diskbalance+meta.mem_netbalance+meta.disk_netbalance; \
     meta.balancescore##num=meta.balancescore##num*P; \
     meta.balancescore##num=10000*P*Q-meta.balancescore##num; \
 } \
 cluster_ID##num.read(meta.delayratio,5); \
 meta.netscore##num=((int<32>)meta.delayratio)*(10000/1000/10); \
 meta.netscore##num=10000*P*Q-meta.netscore##num*P*Q

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata);
    }
    
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl -1;
    }

    action swap_mac(){
        macAddr_t tmp;
        tmp = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = tmp;
        ip4Addr_t tmp1;
        tmp1 = hdr.ipv4.srcAddr;
        hdr.ipv4.srcAddr = hdr.ipv4.dstAddr;
        hdr.ipv4.dstAddr = tmp1;
        standard_metadata.egress_spec = standard_metadata.ingress_port;
        hdr.ipv4.ttl = hdr.ipv4.ttl -1;
        hdr.ipv4.totalLen=hdr.ipv4.totalLen-12;
    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    apply {
        if (hdr.ipv4.isValid()&&hdr.ipv4.protocol!=252){
            ipv4_lpm.apply();
        }
        
        if (hdr.ipv4.protocol==252&&hdr.user.isValid()){
            swap_mac();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    
    CLUSTER_REGISTER(1);
    CLUSTER_REGISTER(2);
    CLUSTER_REGISTER(3);

    register<int<32>>(12) cunscore;
    
    action drop() {
        mark_to_drop(standard_metadata);
    }

    table drop_table{
        actions = {
            drop;
        }
        size =1;
        default_action = drop();
    }

    apply {
        if (hdr.ipv4.protocol==251&&hdr.cluster.isValid()){
            bit<32> ip1;
            bit<32> ip2;
            bit<32> ip3;
            cluster_ID1.read(ip1,0);
            cluster_ID2.read(ip2,0);
            cluster_ID3.read(ip3,0);
            if(hdr.ipv4.srcAddr==ip1){
                CLUSTER_WRITECHANGE(1);
            }
            else if(hdr.ipv4.srcAddr==ip2){
                CLUSTER_WRITECHANGE(2);
            }
            else if(hdr.ipv4.srcAddr==ip3){
                CLUSTER_WRITECHANGE(3);
            }
            else{
                if(ip1==0){
                    CLUSTER_WRITECHANGE(1);
                }
                else if(ip2==0){
                    CLUSTER_WRITECHANGE(2);
                }
                else{
                    CLUSTER_WRITECHANGE(3);
                }
            }
            drop_table.apply();
        }

        if(hdr.ipv4.protocol==252){
            CLUSTER_SCORE(1);
            CLUSTER_SCORE(2);
            CLUSTER_SCORE(3);
            meta.cluster1_score=meta.leastscore1+meta.balancescore1+meta.netscore1;
            meta.cluster2_score=meta.leastscore2+meta.balancescore2+meta.netscore2;
            meta.cluster3_score=meta.leastscore3+meta.balancescore3+meta.netscore3;
            cunscore.write(0,meta.leastscore1);
            cunscore.write(1,meta.leastscore2);
            cunscore.write(2,meta.leastscore3);
            cunscore.write(3,meta.balancescore1);
            cunscore.write(4,meta.balancescore2);
            cunscore.write(5,meta.balancescore3);
            cunscore.write(6,meta.netscore1);
            cunscore.write(7,meta.netscore2);
            cunscore.write(8,meta.netscore3);
            cunscore.write(9,meta.cluster1_score);
            cunscore.write(10,meta.cluster2_score);
            cunscore.write(11,meta.cluster3_score);
            meta.maxscore=meta.cluster1_score;
            cluster_ID1.read(meta.destinationIP,0);
            if(meta.cluster2_score>meta.maxscore){
                meta.maxscore=meta.cluster2_score;
                cluster_ID2.read(meta.destinationIP,0);
            }
            if(meta.cluster3_score>meta.maxscore){
                meta.maxscore=meta.cluster3_score;
                cluster_ID3.read(meta.destinationIP,0);
            }
            hdr.user.setInvalid();
            hdr.dstip.setValid();
            hdr.dstip.dstIP=meta.destinationIP;
        }
        bit<32> ip1;
        bit<32> ip2;
        bit<32> ip3;
        cluster_ID1.read(ip1,0);
        cluster_ID2.read(ip2,0);
        cluster_ID3.read(ip3,0);
        if(hdr.ipv4.dstAddr==ip1){
            cluster_ID1.write(5,standard_metadata.deq_timedelta);
        }
        if(hdr.ipv4.dstAddr==ip2){
            cluster_ID2.write(5,standard_metadata.deq_timedelta);
        }
        if(hdr.ipv4.dstAddr==ip3){
            cluster_ID3.write(5,standard_metadata.deq_timedelta);
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
              hdr.ipv4.tos,
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
    }
}


/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {

        //parsed headers have to be added again into the packet.
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.cluster);
        packet.emit(hdr.user);
        packet.emit(hdr.dstip);
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
