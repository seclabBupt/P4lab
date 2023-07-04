/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

/*
 * We provide 3 different hash modules in this solution to demostrate
 * how one can modularize a P4 program.
 * 
 * The hash module is supposed to define the following:
 *  1) Controls that will be called from the ingress() control to calculate
 *     the hash. If they are not needed, then they should be empty
 *     1) calc_ipv4_hashes()   -- called for IPv4 packets only
 *     2) calc_ipv6_hashes()   -- called for IPv6 packets only
 *     3) calc_common_hashes() -- called for all packets
 *     In all the cases the controls fill in struct selector_hashes_t
 * 
 *  2) Action Selector lag_ecmp_sel that will be used as the implementation
 *     attribute for the table that performs selection
 *
 *  3) A constant SCRAMBLER_ENABLE indicating whether to enable or disable the 
 *     non-linear hash scrambler. Usually it should be enabled, but for
 *     algorithms like round-robin it should be disabled. Ideally, it should've
 *     been a part of the action selector definition, but currently it is not
 * 
 * By defining the actual selector, the hash module encapsulates everything 
 * with regards to member selection, including:
 *  1) The input to the hash calculation algorithm, including the ability 
 *     to dynamically change it
 *  2) The hash algorithm itself, including the ability to dynamically 
 *     change it.
 *  3) The member selection algorithm (fair or resilient)
 */

/*************************************************************************
 ************* M O D U L A R I T Y   A N D   P R O F I L E S  ************
 *************************************************************************/

#define IPV4_IPV6_HASH   1
#define RANDOM_HASH      2
#define ROUND_ROBIN_HASH 3
#define NO_HASH          4

#if defined(USE_NO_HASH)
  #define HASHING NO_HASH
#elif defined(USE_IPV4_IPV6)
  #define HASHING IPV4_IPV6_HASH
#elif defined(USE_RANDOM)
  #define HASHING RANDOM_HASH
#elif defined(USE_ROUND_ROBIN)
  #define HASHING ROUND_ROBIN_HASH
#else 
  #define HASHING IPV4_IPV6_HASH
#endif

#ifndef RESILIENT_SELECTION
#define RESILIENT_SELECTION 0
#endif

#ifndef MAX_PROFILE_MEMBERS
#define MAX_PROFILE_MEMBERS 2048
#endif

#ifndef MAX_GROUP_SIZE
#define MAX_GROUP_SIZE 120
#endif

#ifndef MAX_GROUPS
#define MAX_GROUPS 1024 
#endif

/* The number of required hash bits depends on both the selection algorithm 
 * (resilient or fair) and the maximum group size
 *
 * The rules are as follows:
 *
 * if MAX_GROUP_SZIE <= 120:      subgroup_select_bits = 0
 * elif MAX_GROUP_SIZE <= 3840:   subgroup_select_bits = 10
 * elif MAX_GROUP_SIZE <= 119040: subgroup_select_bits = 15
 * else: ERROR
 *
 * The rules for the hash size are:
 *
 * FAIR:      14 + subgroup_select_bits
 * RESILIENT: 51 + subgroup_select_bits
 *
 */
#if RESILIENT_SELECTION == 0
  const SelectorMode_t SELECTION_MODE = SelectorMode_t.FAIR;
  #define BASE_HASH_WIDTH 14
#else
  const SelectorMode_t SELECTION_MODE = SelectorMode_t.RESILIENT;
  #define BASE_HASH_WIDTH 51
#endif /* RESILIENT_SELECTION */

#if MAX_GROUP_SIZE <= 120
  #define SUBGROUP_BITS 0
#elif MAX_GROUP_SIZE <= 3840
  #define SUBGROUP_BITS 10
#elif MAX_GROUP_SIZE <= 119040
  #define SUBGROUP_BITS 15
#else
  #error "Maximum Group Size cannot exceed 119040 members on Tofino"
#endif /* MAX_GROUP_SIZE */

/*
 * HASH_WIDTH final definition
 */
#define HASH_WIDTH (BASE_HASH_WIDTH + SUBGROUP_BITS)

/* 
 * Since we will be calculating hash in 32-bit pieces, we will have this 
 * definition, which will be either bit<32>, bit<64> or bit<96> depending
 * on HASH_WIDTH
 */
typedef bit<(((HASH_WIDTH + 32)/32)*32)> selector_hash_t;

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
*************************************************************************/
enum bit<16> ether_type_t {
    TPID = 0x8100,
    IPV4 = 0x0800,
    IPV6 = 0x86DD
}

enum bit<8>  ip_proto_t {
    ICMP  = 1,
    IGMP  = 2,
    TCP   = 6,
    UDP   = 17
}

typedef bit<48>   mac_addr_t;
typedef bit<32>   ipv4_addr_t;
typedef bit<128>  ipv6_addr_t;

typedef bit<16>   nexthop_id_t;


/******** TABLE SIZING **********/
const bit<32> LAG_ECMP_SIZE = 16384;

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
    bit<4>       version;
    bit<4>       ihl;
    bit<8>       diffserv;
    bit<16>      total_len;
    bit<16>      identification;
    bit<3>       flags;
    bit<13>      frag_offset;
    bit<8>       ttl;
    ip_proto_t   protocol;
    bit<16>      hdr_checksum;
    ipv4_addr_t  src_addr;
    ipv4_addr_t  dst_addr;
}

header ipv4_options_h { 
    varbit<320> data;
}

header ipv6_h {
    bit<4>       version;
    bit<8>       traffic_class;
    bit<20>      flow_label;
    bit<16>      payload_len;
    ip_proto_t   next_hdr;
    bit<8>       hop_limit;
    ipv6_addr_t  src_addr;
    ipv6_addr_t  dst_addr;
}

header icmp_h {
    bit<16>  type_code;
    bit<16>  checksum;
}

header igmp_h {
    bit<16>  type_code;
    bit<16>  checksum;
}

header tcp_h {
    bit<16>  src_port;
    bit<16>  dst_port;
    bit<32>  seq_no;
    bit<32>  ack_no;
    bit<4>   data_offset;
    bit<4>   res;
    bit<8>   flags;
    bit<16>  window;
    bit<16>  checksum;
    bit<16>  urgent_ptr;
}

header udp_h {
    bit<16>  src_port;
    bit<16>  dst_port;
    bit<16>  len;
    bit<16>  checksum;
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    ethernet_h         ethernet;
    vlan_tag_h[2]      vlan_tag;
    ipv4_h             ipv4;
    ipv4_options_h     ipv4_options;
    ipv6_h             ipv6;
    icmp_h             icmp;
    igmp_h             igmp;
    tcp_h              tcp;
    udp_h              udp;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct l4_lookup_t {
    bit<16>  word_1;
    bit<16>  word_2;
}

struct my_ingress_metadata_t {
    l4_lookup_t   l4_lookup;
    bit<1>        first_frag;
    bit<1>        ipv4_checksum_err;
}

    /***********************  P A R S E R  **************************/

parser IngressParser(packet_in        pkt,
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

    /* User Metadata Initialization */
    state meta_init {
        meta.l4_lookup         = { 0, 0 };
        meta.first_frag        = 0;
        meta.ipv4_checksum_err = 0;
        
        transition parse_ethernet;
    }

    /* Packet parsing */
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.TPID :  parse_vlan_tag;
            ether_type_t.IPV4 :  parse_ipv4;
            ether_type_t.IPV6 :  parse_ipv6;
            default :  accept;
        }
    }

    state parse_vlan_tag {
        pkt.extract(hdr.vlan_tag.next);
        transition select(hdr.vlan_tag.last.ether_type) {
            ether_type_t.TPID :  parse_vlan_tag;
            ether_type_t.IPV4 :  parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        ipv4_checksum.add(hdr.ipv4);
        
        transition select(hdr.ipv4.ihl) {
            5         : parse_ipv4_no_options;
            6 &&& 0xE : parse_ipv4_options;
            8 &&& 0x8 : parse_ipv4_options;
            default   : reject;
        }
    }

    state parse_ipv4_options {
        pkt.extract(hdr.ipv4_options, ((bit<32>)hdr.ipv4.ihl - 5) * 32);

        /* Checksum Verification */
        ipv4_checksum.add(hdr.ipv4_options);

        transition parse_ipv4_no_options;
    }

    state parse_ipv4_no_options {
        /* Checksum Verification */
        meta.ipv4_checksum_err = (bit<1>)ipv4_checksum.verify();
        
        meta.l4_lookup = pkt.lookahead<l4_lookup_t>();

        transition select(hdr.ipv4.frag_offset, hdr.ipv4.protocol) {
            ( 0, ip_proto_t.ICMP ) : parse_icmp;
            ( 0, ip_proto_t.IGMP ) : parse_igmp;
            ( 0, ip_proto_t.TCP  ) : parse_tcp;
            ( 0, ip_proto_t.UDP  ) : parse_udp;
            ( 0, _               ) : parse_first_fragment;
            default : accept;
        }
    }

    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        meta.l4_lookup = pkt.lookahead<l4_lookup_t>();

        transition select(hdr.ipv6.next_hdr) {
            ip_proto_t.ICMP : parse_icmp;
            ip_proto_t.IGMP : parse_igmp;
            ip_proto_t.TCP  : parse_tcp;
            ip_proto_t.UDP  : parse_udp;
            default : parse_first_fragment;
        }
    }
    
    state parse_first_fragment {
        meta.first_frag = 1;
        transition accept;
    }

    state parse_icmp {
        pkt.extract(hdr.icmp);
        transition parse_first_fragment;
    }
    
    state parse_igmp {
        pkt.extract(hdr.igmp);
        meta.first_frag = 1;
        transition parse_first_fragment;
    }
    
    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition parse_first_fragment;
    }
    
    state parse_udp {
        pkt.extract(hdr.udp);
        transition parse_first_fragment;
    }
}

    /***************** M A T C H - A C T I O N  *********************/

/* Include the proper hashing module */
#if HASHING == IPV4_IPV6_HASH
  #include "ipv4_ipv6_hash.p4"
#elif HASHING == RANDOM_HASH
  #include "random_hash.p4"
#elif HASHING == ROUND_ROBIN_HASH
  #include "round_robin_hash.p4"
#elif HASHING == NO_HASH
  #include "no_hash.p4"
#else
  #error Unknown hashing module (HASHING)
#endif

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
    nexthop_id_t       nexthop_id = 0;
    bit<8>             ttl_dec = 0;
    
#ifndef P4C_2228_FIXED
    @pa_container_size("ingress", "hash_0", 32)
#endif
    selector_hash_t  hash = 0;
    
    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
        ttl_dec = 0;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action l3_switch(PortId_t port, bit<48> new_mac_da, bit<48> new_mac_sa) {
        hdr.ethernet.dst_addr = new_mac_da;
        hdr.ethernet.src_addr = new_mac_sa;
        ttl_dec = 1;
        ig_tm_md.ucast_egress_port = port;
        
    }

    action set_nexthop(nexthop_id_t nexthop) {
        nexthop_id = nexthop;
    }
    
    table ipv4_host {
        key = { hdr.ipv4.dst_addr : exact; }
        actions = {
            set_nexthop;
            @defaultonly NoAction;
        }
        const default_action = NoAction();
        size = 65536;
    }

    table ipv4_lpm {
        key     = { hdr.ipv4.dst_addr : lpm; }
        actions = { set_nexthop; }
        
        default_action = set_nexthop(0);
        size           = 12288;
    }

    table ipv6_host {
        key = { hdr.ipv6.dst_addr : exact; }
        actions = {
            set_nexthop;
            @defaultonly NoAction;
        }
        const default_action = NoAction();
        size = 32768;
    }

    table ipv6_lpm {
        key     = { hdr.ipv6.dst_addr : lpm; }
        actions = { set_nexthop; }
        
        default_action = set_nexthop(0);
        size           = 4096;
    }

    ActionProfile(size = MAX_PROFILE_MEMBERS) lag_ecmp;
    Hash<bit<HASH_WIDTH>>(HashAlgorithm_t.IDENTITY) final_hash;

    ActionSelector(
        action_profile = lag_ecmp,
        hash           = final_hash,
        mode           = SELECTION_MODE,
        max_group_size = MAX_GROUP_SIZE,
        num_groups     = MAX_GROUPS) lag_ecmp_sel;
        
    #ifdef SCRAMBLE_ENABLE
    @selector_enable_scramble(SCRAMBLE_ENABLE)
    #endif
    table nexthop {
        key = {
            nexthop_id : exact;
           
            hash       : selector;
        }
        actions = { send; drop; l3_switch; }
        size = 16384;
        implementation = lag_ecmp_sel;
    }

    action decrement(inout bit<8> what, in bit<8> dec_amount) {
        what = what - dec_amount;
    }

    /* The algorithm */
    apply {
        if (hdr.ipv4.isValid()) {
            calc_ipv4_hashes.apply(hdr, meta, hash);
            if (meta.ipv4_checksum_err == 0 && hdr.ipv4.ttl > 1) {
                if (!ipv4_host.apply().hit) {
                    ipv4_lpm.apply();
                }
            }
        } else if (hdr.ipv6.isValid()) {
            calc_ipv6_hashes.apply(hdr, meta, hash);
            if (hdr.ipv6.hop_limit > 1) {
                if (!ipv6_host.apply().hit) {
                    ipv6_lpm.apply();
                }
            }
        }
        
        calc_common_hashes.apply(hdr, meta, hash);
        
        nexthop.apply();

        /* TTL Modifications */
        if (hdr.ipv4.isValid()) {
            decrement(hdr.ipv4.ttl, ttl_dec);
        } else if (hdr.ipv6.isValid()) {
            decrement(hdr.ipv6.hop_limit, ttl_dec);
        }
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
                hdr.ipv4.dst_addr,
                hdr.ipv4_options.data
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
