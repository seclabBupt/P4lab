/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
*************************************************************************/

/* Header Stuff */
enum bit<16> ether_type_t {
    TPID = 0x8100,
    IPV4 = 0x0800,
    ARP  = 0x0806,
    IPV6 = 0x86DD,
    MPLS = 0x8847
}

#ifdef ENUM_IN_ENTRIES
enum bit<8> ip_protocol_t {
    ICMP = 1,
    IGMP = 2,
    TCP  = 6,
    UDP  = 17
}

enum bit<16> arp_opcode_t {
    REQUEST = 1,
    REPLY   = 2
}


enum bit<8> icmp_type_t {
    ECHO_REPLY   = 0,
    ECHO_REQUEST = 8
}
#endif

typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;

/* Metadata and Table Stuff */
const int IPV4_HOST_SIZE = 65536;
const int IPV4_LPM_SIZE  = 12288;

#define NEXTHOP_ID_WIDTH 14
typedef bit<NEXTHOP_ID_WIDTH> nexthop_id_t;
const int NEXTHOP_SIZE = 1 << NEXTHOP_ID_WIDTH;

/*************************************************************************
 ***********************  H E A D E R S  *********************************
 *************************************************************************/
/*  Define all the headers the program will recognize             */
/*  The actual sets of headers processed by each gress can differ */

/* Standard ethernet header */
header ethernet_h {
    mac_addr_t    dst_addr;
    mac_addr_t    src_addr;
    ether_type_t  ether_type;
}

header vlan_tag_h {
    bit<3>        pcp;
    bit<1>        cfi;
    bit<12>       vid;
    ether_type_t  ether_type;
}

header ipv4_h {
    bit<4>          version;
    bit<4>          ihl;
    bit<8>          diffserv;
    bit<16>         total_len;
    bit<16>         identification;
    bit<3>          flags;
    bit<13>         frag_offset;
    bit<8>          ttl;
#ifdef ENUM_IN_ENTRIES
    ip_protocol_t   protocol;
#else
    bit<8>          protocol;
#endif    
    bit<16>         hdr_checksum;
    ipv4_addr_t     src_addr;
    ipv4_addr_t     dst_addr;
}

header ipv4_options_h {
    varbit<320> data;
}

header icmp_h {
#ifdef ENUM_IN_ENTRIES
    icmp_type_t msg_type;
#else
    bit<8>      msg_type;
#endif    
    bit<8>      msg_code;
    bit<16>     checksum;
}

header arp_h {
    bit<16>       hw_type;
    ether_type_t  proto_type;
    bit<8>        hw_addr_len;
    bit<8>        proto_addr_len;
#ifdef ENUM_IN_ENTRIES
    arp_opcode_t  opcode;
#else
    bit<16>       opcode;
#endif
} 

header arp_ipv4_h {
    mac_addr_t   src_hw_addr;
    ipv4_addr_t  src_proto_addr;
    mac_addr_t   dst_hw_addr;
    ipv4_addr_t  dst_proto_addr;
}



/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    ethernet_h         ethernet;
    vlan_tag_h[2]      vlan_tag;
    arp_h              arp;
    arp_ipv4_h         arp_ipv4;
    ipv4_h             ipv4;
#ifdef IPV4_OPTIONS    
    ipv4_options_h     ipv4_options;
#endif    
    icmp_h             icmp;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct my_ingress_metadata_t {
    ipv4_addr_t   dst_ipv4;
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
        meta.dst_ipv4      = 0;
        transition parse_ethernet;
    }
    
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.TPID :  parse_vlan_tag;
            ether_type_t.IPV4 :  parse_ipv4;
            ether_type_t.ARP  :  parse_arp;
            default:  accept;
        }
    }

    state parse_vlan_tag {
        pkt.extract(hdr.vlan_tag.next);
        transition select(hdr.vlan_tag.last.ether_type) {
            ether_type_t.TPID :  parse_vlan_tag;
            ether_type_t.IPV4 :  parse_ipv4;
            ether_type_t.ARP  :  parse_arp;
            default: accept;
        }
    }
    
    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        meta.dst_ipv4 = hdr.ipv4.dst_addr;
        ipv4_checksum.add(hdr.ipv4);
        
        transition select(hdr.ipv4.ihl) {
            0x5 : parse_ipv4_no_options;
#ifdef IPV4_OPTIONS
            0x6 &&& 0xE : parse_ipv4_options;
            0x8 &&& 0x8 : parse_ipv4_options;
#endif            
            default: reject; // Currently the same as accept
        }
    }

#ifdef IPV4_OPTIONS
    state parse_ipv4_options {
        pkt.extract(
            hdr.ipv4_options,
            ((bit<32>)hdr.ipv4.ihl - 32w5) * 32);
        
        ipv4_checksum.add(hdr.ipv4_options);
        transition parse_ipv4_no_options;
    }
#endif
    
    state parse_ipv4_no_options {
        meta.ipv4_csum_err = (bit<1>)ipv4_checksum.verify();
#ifdef PARSER_WAR
        transition select(hdr.ipv4.protocol) {
#ifdef ENUM_IN_ENTRIES
            ( ip_protocol_t.ICMP ) : parse_icmp;
#else
            0x01 : parse_icmp;
#endif            
#else
        transition select(hdr.ipv4.frag_offset, hdr.ipv4.protocol) {
#ifdef ENUM_IN_ENTRIES
            ( 0, ip_protocol_t.ICMP ) : parse_icmp;
#else
            ( 0, 1) : parse_icmp;
#endif            
#endif
            default     : accept;
        }
    }

    state parse_icmp {
        pkt.extract(hdr.icmp);
        transition accept;
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        transition select(hdr.arp.hw_type, hdr.arp.proto_type) {
            (0x0001, ether_type_t.IPV4) : parse_arp_ipv4;
            default: reject; // Currently the same as accept
        }
    }

    state parse_arp_ipv4 {
        pkt.extract(hdr.arp_ipv4);
        meta.dst_ipv4 = hdr.arp_ipv4.dst_proto_addr;
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
    nexthop_id_t    nexthop_id  = 0;
    mac_addr_t      mac_da      = 0;
    mac_addr_t      mac_sa      = 0;
    PortId_t        egress_port = 511; /* Non-existent port */
    bit<8>          ttl_dec     = 0;

    /****************** IPv4 Lookup ********************/
    action set_nexthop(nexthop_id_t nexthop) {
        nexthop_id = nexthop;
    }
    
    table ipv4_host {
        key = { meta.dst_ipv4 : exact; }
        actions = {
            set_nexthop;
            @defaultonly NoAction;
        }
        const default_action = NoAction();
        size = IPV4_HOST_SIZE;
    }

    table ipv4_lpm {
        key     = { meta.dst_ipv4 : lpm; }
        actions = { set_nexthop; }
        
        default_action = set_nexthop(0);
        size           = IPV4_LPM_SIZE;
    }

    /****************** IPv4 Lookup ********************/
    action send(PortId_t port) {
        mac_da      = hdr.ethernet.dst_addr;
        mac_sa      = hdr.ethernet.src_addr;
        egress_port = port;
        ttl_dec     = 0;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action l3_switch(PortId_t port, bit<48> new_mac_da, bit<48> new_mac_sa) {
        mac_da      = new_mac_da;
        mac_sa      = new_mac_sa;
        egress_port = port;
        ttl_dec     = 1;        
    }

    table nexthop {
        key = { nexthop_id : exact; }
        actions = { send; drop; l3_switch; }
        size = NEXTHOP_SIZE;
    }

    /****************** Metadata Processing ********************/

    action send_back() {
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
    }

    action forward_ipv4() {
        hdr.ethernet.dst_addr      = mac_da;
        hdr.ethernet.src_addr      = mac_sa;
        hdr.ipv4.ttl               = hdr.ipv4.ttl |-| ttl_dec;
        ig_tm_md.ucast_egress_port = egress_port;
    }

    action send_arp_reply() {
        hdr.ethernet.dst_addr = hdr.arp_ipv4.src_hw_addr;
        hdr.ethernet.src_addr = mac_da;

#ifdef ENUM_IN_TABLES       
        hdr.arp.opcode = arp_opcode_t.REPLY;
#else
        hdr.arp.opcode = 1;
#endif 
        hdr.arp_ipv4.dst_hw_addr    = hdr.arp_ipv4.src_hw_addr;
        hdr.arp_ipv4.dst_proto_addr = hdr.arp_ipv4.src_proto_addr;
        hdr.arp_ipv4.src_hw_addr    = mac_da;
        hdr.arp_ipv4.src_proto_addr = meta.dst_ipv4;

        send_back();
    }

    action send_icmp_echo_reply() {
        mac_addr_t  tmp_mac  = hdr.ethernet.src_addr;
        ipv4_addr_t tmp_ipv4 = hdr.ipv4.src_addr;

        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = tmp_mac;

        hdr.ipv4.src_addr = hdr.ipv4.dst_addr;
        hdr.ipv4.dst_addr = tmp_ipv4;
        
        hdr.ipv4.ttl      = hdr.ipv4.ttl |-| ttl_dec; /* Optional */
#ifdef ENUM_IN_TABLES       
        hdr.icmp.msg_type = icmp_type_t.ECHO_REPLY;
#else
        hdr.icmp.msg_type = 0;
#endif        
        hdr.icmp.checksum = 0;

        send_back();
    }

    table forward_or_respond {
        key = {
            hdr.arp.isValid()       : exact;
            hdr.arp_ipv4.isValid()  : exact;
            hdr.ipv4.isValid()      : exact;
            hdr.icmp.isValid()      : exact;
            hdr.arp.opcode          : ternary;
            hdr.icmp.msg_type       : ternary;
        }
        actions = {
            forward_ipv4;
            send_arp_reply;
            send_icmp_echo_reply;
            drop;
        }
        const entries = {
            (false, false, true,  false, _, _) :
            forward_ipv4();
 #ifdef ENUM_IN_ENTRIES           
            (true,  true,  false, false, arp_opcode_t.REQUEST, _ ) :
            send_arp_reply();
            
            (false, false, true,   true, _, icmp_type_t.ECHO_REQUEST) :
            send_icmp_echo_reply();
#else
            (true,  true,  false, false, 1, _ ) :
            send_arp_reply();
            
            (false, false, true,   true, _, 8) :
            send_icmp_echo_reply();
            
#endif
            (false, false, true,   true, _, _) :
            forward_ipv4();
        }
        default_action = drop();
    }
    
    /* The algorithm */
    apply {
        if (meta.ipv4_csum_err == 0 && hdr.ipv4.ttl > 1) {
            if (!ipv4_host.apply().hit) {
                ipv4_lpm.apply();
            }
        }

        nexthop.apply();
        forward_or_respond.apply();
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
                /* Adding hdr.ipv4_options.data results in an error */
            });
        pkt.emit(hdr);
    }
}


/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/

struct my_egress_headers_t {
}

    /********  G L O B A L   E G R E S S   M E T A D A T A  *********/

struct my_egress_metadata_t {
}

    /***********************  P A R S E R  **************************/

parser EgressParser(packet_in        pkt,
    /* User */
    out my_egress_headers_t          hdr,
    out my_egress_metadata_t         meta,
    /* Intrinsic */
    out egress_intrinsic_metadata_t  eg_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}

    /***************** M A T C H - A C T I O N  *********************/

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
    apply {
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
