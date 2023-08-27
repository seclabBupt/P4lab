/* -*- P4_16 -*- */
#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
*************************************************************************/
const bit<16> ETHERTYPE_IPV4 = 0x0800;
const bit<8>  TYPE_INFORM  = 251;
const bit<8>  TYPE_REQUEST = 252;

/* Table Sizing */
const int IPV4_LPM_TABLE_SIZE  = 12288;

/*************************************************************************
 ***********************  H E A D E R S  *********************************
 *************************************************************************/
/*  Define all the headers the program will recognize             */
/*  The actual sets of headers processed by each gress can differ */

/* Standard ethernet header */
header ethernet_h {
    bit<48>  dst_addr;
    bit<48>  src_addr;
    bit<16>  ether_type;
}

header ipv4_h {
    bit<4>   version;
    bit<4>   ihl;
    bit<8>   diffserv;
    bit<16>  total_len;
    bit<16>  identification;
    bit<3>   flags;
    bit<13>  frag_offset;
    bit<8>   ttl;
    bit<8>   protocol;
    bit<16>  hdr_checksum;
    bit<32>  src_addr;
    bit<32>  dst_addr;
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
    bit<32> dstIP;
}

header bridged_metadata_t {
	bit<48> ingress_tstamp;
}

header user_metadata_t{
    bit<32> user_CPU;
    bit<32> user_MEM;
    bit<32> user_DISK;
    bit<32> user_NET;
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    ethernet_h         ethernet;
    ipv4_h             ipv4;
    cluster_t          cluster;
    user_t             user;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct my_ingress_metadata_t {
    bridged_metadata_t bridged_metadata;
    bit<1>        ipv4_csum_err;
}

    /***********************  P A R S E R  **************************/

parser IngressParser(packet_in      pkt,
    /* User */
    out my_ingress_headers_t          hdr,
    out my_ingress_metadata_t         meta,
    /* Intrinsic */
    out ingress_intrinsic_metadata_t  ig_intr_md)
{
    Checksum() ipv4_checksum;
    
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition meta_init;
    }

    state meta_init {
        meta.ipv4_csum_err = 0;
        meta.bridged_metadata.ingress_tstamp=0;
        transition parse_ethernet;
    }
    
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4 :  parse_ipv4;
            default        :  accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        ipv4_checksum.add(hdr.ipv4);
        meta.ipv4_csum_err = (bit<1>)ipv4_checksum.verify();
        transition select(hdr.ipv4.protocol){
            TYPE_INFORM: cluster;
            TYPE_REQUEST: user;
            default: accept;
        }
    }

    state cluster {
       pkt.extract(hdr.cluster);
       transition accept;
    }

    state user {
       pkt.extract(hdr.user);
       transition accept;
    }
}

    /***************** M A T C H - A C T I O N  *********************/

control Ingress(
    /* User */
    inout my_ingress_headers_t                       hdr,
    inout my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md)
{
    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action l3_switch(PortId_t port, bit<48> new_mac_da) {
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr=new_mac_da;
        hdr.ipv4.ttl=hdr.ipv4.ttl-1;
        send(port); 
    }

    action swap_mac1(){
        bit<48> tmp;
        tmp = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = tmp;
        bit<32> tmp1;
        tmp1 = hdr.ipv4.src_addr;
        hdr.ipv4.src_addr = hdr.ipv4.dst_addr;
        hdr.ipv4.dst_addr = tmp1;
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
        hdr.ipv4.ttl = hdr.ipv4.ttl -1;
    }

    action swap_mac(){
        bit<48> tmp;
        tmp = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = tmp;
        bit<32> tmp1;
        tmp1 = hdr.ipv4.src_addr;
        hdr.ipv4.src_addr = hdr.ipv4.dst_addr;
        hdr.ipv4.dst_addr = tmp1;
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
        hdr.ipv4.ttl = hdr.ipv4.ttl -1;
        hdr.ipv4.total_len=hdr.ipv4.total_len-12;
    }

    table ipv4_lpm {
        key     = { hdr.ipv4.dst_addr : lpm; }
        actions = { drop; l3_switch; }
        
        default_action = drop();
        size           = IPV4_LPM_TABLE_SIZE;
    }

    /* The algorithm */
    apply {
        if (hdr.ipv4.isValid()) {
            if (meta.ipv4_csum_err == 0 && hdr.ipv4.ttl > 1) {
                if (hdr.ipv4.protocol!=251&&hdr.ipv4.protocol!=252){
                    ipv4_lpm.apply();
                }
                if (hdr.ipv4.protocol==251&&hdr.cluster.isValid()){
                    swap_mac1();
                }    
                if (hdr.ipv4.protocol==252&&hdr.user.isValid()){
                    swap_mac();
                }
            }
        }
        meta.bridged_metadata.setValid();
        meta.bridged_metadata.ingress_tstamp=ig_prsr_md.global_tstamp;
    }
}

    /*********************  D E P A R S E R  ************************/

control IngressDeparser(packet_out pkt,
    /* User */
    inout my_ingress_headers_t                       hdr,
    in    my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md)
{
    Checksum() ipv4_checksum;
    
    apply {
        hdr.ipv4.hdr_checksum = ipv4_checksum.update({
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr
            });
        pkt.emit(meta.bridged_metadata);
        pkt.emit(hdr);
    }
}


/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/

struct my_egress_headers_t {
    ethernet_h         ethernet;
    ipv4_h             ipv4;
    cluster_t          cluster;
    user_t             user;
    dstip_t            dstip;
}

    /********  G L O B A L   E G R E S S   M E T A D A T A  *********/

struct my_egress_metadata_t {
    user_metadata_t user_metadata;
    bridged_metadata_t bridged_metadata;
}

    /***********************  P A R S E R  **************************/

parser EgressParser(packet_in      pkt,
    /* User */
    out my_egress_headers_t          hdr,
    out my_egress_metadata_t         meta,
    /* Intrinsic */
    out egress_intrinsic_metadata_t  eg_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(eg_intr_md);
        transition init_meta;
    }

    state init_meta {
        meta.user_metadata.user_CPU=0;
        meta.user_metadata.user_MEM=0;
        meta.user_metadata.user_DISK=0;
        meta.user_metadata.user_NET=0;

        meta.bridged_metadata.ingress_tstamp=0;
        transition parse_bridge;
    }

    state parse_bridge {
        pkt.extract(meta.bridged_metadata);
        transition parse_ethernet;
    }
    
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4 :  parse_ipv4;
            default        :  accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol){
            TYPE_INFORM: cluster;
            TYPE_REQUEST: user;
            default: accept;
        }
    }

    state cluster {
       pkt.extract(hdr.cluster);
       transition accept;
    }

    state user {
       pkt.extract(meta.user_metadata);
       transition accept;
    }
}

    /***************** M A T C H - A C T I O N  *********************/
struct delay_meta_t{
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

    bit<32> delayratio1;
    bit<32> delayratio2;
    bit<32> delayratio3;

    bit<32> ip1;
    bit<32> ip2;
    bit<32> ip3;

    bit<32> delay_time1;
    bit<32> delay_time2;
    bit<32> delay_time3;
}

control Egress(
    /* User */
    inout my_egress_headers_t                          hdr,
    inout my_egress_metadata_t                         meta,
    /* Intrinsic */    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md)
{
    delay_meta_t delay_meta;

    Register<bit<32>, bit<1>>(1) cluster_cpu1;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_cpu1) update_cluster_cpu1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterCPU; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_cpu1) read_cluster_cpu1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_CPU>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_cpu1(){
        delay_meta.clusterCPU1 = update_cluster_cpu1.execute(0);
    }
    action read_cpu1(){
        delay_meta.clusterCPU1 = read_cluster_cpu1.execute(0);
    }
    
    Register<bit<32>, bit<1>>(1) cluster_cpu2;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_cpu2) update_cluster_cpu2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterCPU; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_cpu2) read_cluster_cpu2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_CPU>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_cpu2(){
        delay_meta.clusterCPU2 = update_cluster_cpu2.execute(0);
    }
    action read_cpu2(){
        delay_meta.clusterCPU2 = read_cluster_cpu2.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_cpu3;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_cpu3) update_cluster_cpu3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterCPU; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_cpu3) read_cluster_cpu3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_CPU>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_cpu3(){
        delay_meta.clusterCPU3 = update_cluster_cpu3.execute(0);
    }
    action read_cpu3(){
        delay_meta.clusterCPU3 = read_cluster_cpu3.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_mem1;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_mem1) update_cluster_mem1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterMEM; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_mem1) read_cluster_mem1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_MEM>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_mem1(){
        delay_meta.clusterMEM1 = update_cluster_mem1.execute(0);
    }
    action read_mem1(){
        delay_meta.clusterMEM1 = read_cluster_mem1.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_mem2;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_mem2) update_cluster_mem2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterMEM; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_mem2) read_cluster_mem2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_MEM>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_mem2(){
        delay_meta.clusterMEM2 = update_cluster_mem2.execute(0);
    }
    action read_mem2(){
        delay_meta.clusterMEM2 = read_cluster_mem2.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_mem3;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_mem3) update_cluster_mem3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterMEM; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_mem3) read_cluster_mem3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_MEM>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_mem3(){
        delay_meta.clusterMEM3 = update_cluster_mem3.execute(0);
    }
    action read_mem3(){
        delay_meta.clusterMEM3 = read_cluster_mem3.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_disk1;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_disk1) update_cluster_disk1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterDISK; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_disk1) read_cluster_disk1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_DISK>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_disk1(){
        delay_meta.clusterDISK1 = update_cluster_disk1.execute(0);
    }
    action read_disk1(){
        delay_meta.clusterDISK1 = read_cluster_disk1.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_disk2;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_disk2) update_cluster_disk2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterDISK; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_disk2) read_cluster_disk2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_DISK>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_disk2(){
        delay_meta.clusterDISK2 = update_cluster_disk2.execute(0);
    }
    action read_disk2(){
        delay_meta.clusterDISK2 = read_cluster_disk2.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_disk3;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_disk3) update_cluster_disk3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterDISK; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_disk3) read_cluster_disk3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_DISK>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_disk3(){
        delay_meta.clusterDISK3 = update_cluster_disk3.execute(0);
    }
    action read_disk3(){
        delay_meta.clusterDISK3 = read_cluster_disk3.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_net1;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_net1) update_cluster_net1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterNET; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_net1) read_cluster_net1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_NET>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_net1(){
        delay_meta.clusterNET1 = update_cluster_net1.execute(0);
    }
    action read_net1(){
        delay_meta.clusterNET1 = read_cluster_net1.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_net2;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_net2) update_cluster_net2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterNET; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_net2) read_cluster_net2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_NET>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_net2(){
        delay_meta.clusterNET2 = update_cluster_net2.execute(0);
    }
    action read_net2(){
        delay_meta.clusterNET2 = read_cluster_net2.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_net3;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_net3) update_cluster_net3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = hdr.cluster.clusterNET; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_net3) read_cluster_net3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(meta.user_metadata.user_NET>value){
                read_value=0;
            }
            else{
                read_value=1;
            }
        }
    };
    action update_net3(){
        delay_meta.clusterNET3 = update_cluster_net3.execute(0);
    }
    action read_net3(){
        delay_meta.clusterNET3 = read_cluster_net3.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_ip1;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_ip1) write_cluster_ip1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = 3232261130; 
            read_value = value;
        }
    };
    action write_ip1(){
        delay_meta.ip1 = write_cluster_ip1.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_ip2;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_ip2) write_cluster_ip2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = 3232261150; 
            read_value = value;
        }
    };
    action write_ip2(){
        delay_meta.ip2 = write_cluster_ip2.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_ip3;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_ip3) write_cluster_ip3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = 3232261160; 
            read_value = value;
        }
    };
    action write_ip3(){
        delay_meta.ip3 = write_cluster_ip3.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_delay1;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_delay1) update_cluster_delay1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = delay_meta.delay_time1; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_delay1) read_cluster_delay1 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(value<5000000){
                read_value=1;
            }
            else{
                read_value=0;
            }
        }
    };
    action update_delay1(){
        delay_meta.delayratio1 = update_cluster_delay1.execute(0);
    }
    action read_delay1(){
        delay_meta.delayratio1 = read_cluster_delay1.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_delay2;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_delay2) update_cluster_delay2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = delay_meta.delay_time2; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_delay2) read_cluster_delay2 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(value<5000000){
                read_value=1;
            }
            else{
                read_value=0;
            }
        }
    };
    action update_delay2(){
        delay_meta.delayratio2 = update_cluster_delay2.execute(0);
    }
    action read_delay2(){
        delay_meta.delayratio2 = read_cluster_delay2.execute(0);
    }

    Register<bit<32>, bit<1>>(1) cluster_delay3;
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_delay3) update_cluster_delay3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){ 
            value = delay_meta.delay_time3; 
            read_value = value;
        }
    };
    RegisterAction<bit<32>, bit<1>, bit<32>>(cluster_delay3) read_cluster_delay3 = { 
        void apply(inout bit<32> value, out bit<32> read_value){
            if(value<5000000){
                read_value=1;
            }
            else{
                read_value=0;
            }
        }
    };
    action update_delay3(){
        delay_meta.delayratio3 = update_cluster_delay3.execute(0);
    }
    action read_delay3(){
        delay_meta.delayratio3 = read_cluster_delay3.execute(0);
    }

    #define CLUSTER_WRITECHANGE(num) update_cpu##num(); \
     update_mem##num(); \
     update_disk##num(); \
     update_net##num()
    
    #define CLUSTER_SCORE(num) read_cpu##num(); \
     read_mem##num(); \
     read_disk##num(); \
     read_net##num(); \
     read_delay##num()
    
    action drop() {
        eg_dprsr_md.drop_ctl = 1;
    }

    apply {
        write_ip1();
        write_ip2();
        write_ip3(); 
        if (hdr.ipv4.protocol==251&&hdr.cluster.isValid()){
            if(hdr.ipv4.src_addr==delay_meta.ip1){
                CLUSTER_WRITECHANGE(1);
            }
            else if(hdr.ipv4.src_addr==delay_meta.ip2){
                CLUSTER_WRITECHANGE(2);
            }
            else{
                CLUSTER_WRITECHANGE(3);
            }
        }
        else if(hdr.ipv4.protocol==252){
            CLUSTER_SCORE(1);
            CLUSTER_SCORE(2);
            CLUSTER_SCORE(3);
            bit<1> flag1;
            bit<1> flag2;
            bit<1> flag3;
            flag1=1;
            flag2=1;
            flag3=1;
            if(delay_meta.clusterCPU1==0){
                flag1=0;
            }
            if(delay_meta.clusterMEM1==0){
                flag1=0;
            }
            if(delay_meta.clusterDISK1==0){
                flag1=0;
            }
            if(delay_meta.clusterNET1==0){
                flag1=0;
            }
            if(delay_meta.clusterCPU2==0){
                flag2=0;
            }
            if(delay_meta.clusterMEM2==0){
                flag2=0;
            }
            if(delay_meta.clusterDISK2==0){
                flag2=0;
            }
            if(delay_meta.clusterNET2==0){
                flag2=0;
            }
            if(delay_meta.clusterCPU3==0){
                flag3=0;
            }
            if(delay_meta.clusterMEM3==0){
                flag3=0;
            }
            if(delay_meta.clusterDISK3==0){
                flag3=0;
            }
            if(delay_meta.clusterNET3==0){
                flag3=0;
            }
            bit<1> tag1;
            bit<1> tag2;
            bit<1> tag3;
            tag1=0;
            tag2=0;
            tag3=0;
            if(delay_meta.delayratio1==1){
                tag1=1;
            }
            if(delay_meta.delayratio2==1){
                tag2=1;
            }
            if(delay_meta.delayratio1==1){
                tag2=1;
            }
            hdr.dstip.setValid();
            hdr.dstip.dstIP=delay_meta.ip1;
            if(flag1==1&&tag1==1){
                hdr.dstip.dstIP=delay_meta.ip1;
            }
            else if(flag2==1&&tag2==1){
                hdr.dstip.dstIP=delay_meta.ip2;
            }
            else if(flag3==1&&tag3==1){
                hdr.dstip.dstIP=delay_meta.ip3;
            }
            else{
                if(flag1==1){
                    hdr.dstip.dstIP=delay_meta.ip1;
                }
                else if(flag2==1){
                    hdr.dstip.dstIP=delay_meta.ip2;
                }
                else if(flag3==1){
                    hdr.dstip.dstIP=delay_meta.ip3;
                }
                else{
                   hdr.dstip.dstIP=delay_meta.ip1; 
                }
            }
        }
        else{
            if(hdr.ipv4.dst_addr==delay_meta.ip1){
                delay_meta.delay_time1=(bit<32>)(eg_prsr_md.global_tstamp-meta.bridged_metadata.ingress_tstamp);
                update_delay1();
            }
            if(hdr.ipv4.dst_addr==delay_meta.ip2){
                delay_meta.delay_time2=(bit<32>)(eg_prsr_md.global_tstamp-meta.bridged_metadata.ingress_tstamp);
                update_delay2();
            }
            if(hdr.ipv4.dst_addr==delay_meta.ip3){
                delay_meta.delay_time3=(bit<32>)(eg_prsr_md.global_tstamp-meta.bridged_metadata.ingress_tstamp);
                update_delay3();
            }
        }
    }
}

    /*********************  D E P A R S E R  ************************/

control EgressDeparser(packet_out pkt,
    /* User */
    inout my_egress_headers_t                       hdr,
    in    my_egress_metadata_t                      meta,
    /* Intrinsic */
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md)
{
    Checksum() ipv4_checksum;
    
    apply {
        pkt.emit(hdr);
    }
}


/************ F I N A L   P A C K A G E ******************************/
Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;
