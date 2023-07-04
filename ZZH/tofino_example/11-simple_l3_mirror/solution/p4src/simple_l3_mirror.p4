/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
const bit<16> ETHERTYPE_TPID   = 0x8100;
const bit<16> ETHERTYPE_IPV4   = 0x0800;
const bit<16> ETHERTYPE_TO_CPU = 0xBF01;

const int NEXTHOP_ID_WIDTH = 14;
typedef bit<(NEXTHOP_ID_WIDTH)> nexthop_id_t;

/* Table Sizing */
const int IPV4_HOST_TABLE_SIZE = 131072;
const int IPV4_LPM_TABLE_SIZE  = 12288;

const int IPV6_HOST_TABLE_SIZE = 65536;
const int IPV6_LPM_TABLE_SIZE  = 4096;

const int NEXTHOP_TABLE_SIZE   = 1 << NEXTHOP_ID_WIDTH;

/*************************************************************************
 ***********************  H E A D E R S  *********************************
 *************************************************************************/

/*  Define all the headers the program will recognize             */
/*  The actual sets of headers processed by each gress can differ */

/* Standard ethernet header */
header ethernet_h {
    bit<48>   dst_addr;
    bit<48>   src_addr;
    bit<16>   ether_type;
}

header vlan_tag_h {
    bit<3>   pcp;
    bit<1>   cfi;
    bit<12>  vid;
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

header ipv4_options_h {
    varbit<320> data;
}

header ipv6_h {
    bit<4>   version;
    bit<8>   traffic_class;
    bit<20>  flow_label;
    bit<16>  payload_len;
    bit<8>   next_hdr;
    bit<8>   hop_limit;
    bit<128> src_addr;
    bit<128> dst_addr;
}

/*** Internal Headers ***/

typedef bit<4> header_type_t; 
typedef bit<4> header_info_t; 

const header_type_t HEADER_TYPE_BRIDGE         = 0xB;
const header_type_t HEADER_TYPE_MIRROR_INGRESS = 0xC;
const header_type_t HEADER_TYPE_MIRROR_EGRESS  = 0xD;
const header_type_t HEADER_TYPE_RESUBMIT       = 0xA;

/* 
 * This is a common "preamble" header that must be present in all internal
 * headers. The only time you do not need it is when you know that you are
 * not going to have more than one internal header type ever
 */

#define INTERNAL_HEADER         \
    header_type_t header_type;  \
    header_info_t header_info


header inthdr_h {
    INTERNAL_HEADER;
}

/* Bridged metadata */
header bridge_h {
    INTERNAL_HEADER;
    
#ifdef FLEXIBLE_HEADERS
    @flexible    PortId_t  ingress_port;
#else
    bit<7> pad0; PortId_t ingress_port;
#endif
}

/* Ingress mirroring information */
const bit<3> ING_PORT_MIRROR = 0;  /* Choose between different mirror types */

header ing_port_mirror_h {
    INTERNAL_HEADER;
    
#ifdef FLEXIBLE_HEADERS    
    @flexible     PortId_t    ingress_port;
    @flexible     MirrorId_t  mirror_session;
    @flexible     bit<48>     ingress_mac_tstamp;
    @flexible     bit<48>     ingress_global_tstamp;
#else
    bit<7> pad0;  PortId_t    ingress_port;
    bit<6> pad1;  MirrorId_t  mirror_session;
                  bit<48>     ingress_mac_tstamp;
                  bit<48>     ingress_global_tstamp;    
#endif
}

/* 
 * Custom to-cpu header. This is not an internal header, but it contains 
 * the same information, because it is useful to the control plane
 * Note, that we cannot use @flexible annotation here, since these packets
 * do appear on the wire and thus must have deterministic header format
 */
header to_cpu_h {
    INTERNAL_HEADER;
    bit<6>    pad0; MirrorId_t  mirror_session;
    bit<7>    pad1; PortId_t    ingress_port;
                    bit<48>     ingress_mac_tstamp;
                    bit<48>     ingress_global_tstamp;
                    bit<48>     egress_global_tstamp;
                    bit<16>     pkt_length;
}


/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    bridge_h           bridge;
    ethernet_h         ethernet;
    vlan_tag_h         vlan_tag;
    ipv4_h             ipv4;
    ipv4_options_h     ipv4_options;
    ipv6_h             ipv6;    
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct my_ingress_metadata_t {
    header_type_t  mirror_header_type;
    header_info_t  mirror_header_info;
    PortId_t       ingress_port;
    MirrorId_t     mirror_session;
    bit<48>        ingress_mac_tstamp;
    bit<48>        ingress_global_tstamp;
    bit<1>         ipv4_csum_err;
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
        transition init_meta;
    }

    state init_meta {
        meta = { 0, 0, 0, 0, 0, 0, 0 };

        hdr.bridge.setValid();
        hdr.bridge.header_type  = HEADER_TYPE_BRIDGE;
        hdr.bridge.header_info  = 0;

#ifndef FLEXIBLE_HEADERS
        hdr.bridge.pad0 = 0;
#endif
        hdr.bridge.ingress_port = ig_intr_md.ingress_port; 
        
        transition parse_ethernet;
    }
    
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_TPID:  parse_vlan_tag;
            ETHERTYPE_IPV4:  parse_ipv4;
            default: accept;
        }
    }

    state parse_vlan_tag {
        pkt.extract(hdr.vlan_tag);
        transition select(hdr.vlan_tag.ether_type) {
            ETHERTYPE_IPV4:  parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        ipv4_checksum.add(hdr.ipv4);
        
        transition select(hdr.ipv4.ihl) {
            0x5 : parse_ipv4_no_options;
            0x6 &&& 0xE : parse_ipv4_options;
            0x8 &&& 0x8 : parse_ipv4_options;
            default: reject;
        }
    }

    state parse_ipv4_options {
        pkt.extract(
            hdr.ipv4_options,
            ((bit<32>)hdr.ipv4.ihl - 32w5) * 32);
        
        ipv4_checksum.add(hdr.ipv4_options);
        transition parse_ipv4_no_options;
    }

    state parse_ipv4_no_options {
        meta.ipv4_csum_err = (bit<1>)ipv4_checksum.verify();
        transition accept;
    }

    state parse_ipv6 {
        pkt.extract(hdr.ipv6);

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
    nexthop_id_t    nexthop_id = 0;
    bit<8>          ttl_dec = 0;
    
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
        size = IPV4_HOST_TABLE_SIZE;
    }

    table ipv4_lpm {
        key     = { hdr.ipv4.dst_addr : lpm; }
        actions = { set_nexthop; }
        
        default_action = set_nexthop(0);
        size           = IPV4_LPM_TABLE_SIZE;
    }

    table ipv6_host {
        key = { hdr.ipv6.dst_addr : exact; }
        actions = {
            set_nexthop;
            @defaultonly NoAction;
        }
        const default_action = NoAction();
        size = IPV6_HOST_TABLE_SIZE;
    }

    table ipv6_lpm {
        key     = { hdr.ipv6.dst_addr : lpm; }
        actions = { set_nexthop; }
        
        default_action = set_nexthop(0);
        size           = IPV6_LPM_TABLE_SIZE;
    }

    /*********** NEXTHOP ************/
    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action l3_switch(PortId_t port, bit<48> new_mac_da, bit<48> new_mac_sa) {
        hdr.ethernet.dst_addr = new_mac_da;
        hdr.ethernet.src_addr = new_mac_sa;
        ttl_dec = 1;
        send(port); 
    }

    table nexthop {
        key = { nexthop_id : exact; }
        actions = { send; drop; l3_switch; }
        size = NEXTHOP_TABLE_SIZE;
    }

    /********* MIRRORING ************/
    action acl_mirror(MirrorId_t mirror_session) {
        ig_dprsr_md.mirror_type = ING_PORT_MIRROR;

        meta.mirror_header_type = HEADER_TYPE_MIRROR_INGRESS;
        meta.mirror_header_info = (header_info_t)ING_PORT_MIRROR;

        meta.ingress_port   = ig_intr_md.ingress_port;
        meta.mirror_session = mirror_session;
        
        meta.ingress_mac_tstamp    = ig_intr_md.ingress_mac_tstamp;
        meta.ingress_global_tstamp = ig_prsr_md.global_tstamp;
    }

    action acl_drop_and_mirror(MirrorId_t mirror_session) {
        acl_mirror(mirror_session);
        drop();
    }
    
    table port_acl {
        key = {
            ig_intr_md.ingress_port : ternary;
        }
        actions = {
            acl_mirror; acl_drop_and_mirror; drop; NoAction;
        }
        size = 512;
        default_action = NoAction();
    }
    
    apply {
        if (ig_prsr_md.parser_err == 0) {
            if (hdr.ipv4.isValid()) {
                if (meta.ipv4_csum_err == 0 && hdr.ipv4.ttl > 1) {
                    if (!ipv4_host.apply().hit) {
                        ipv4_lpm.apply();
                    }
                    nexthop.apply();
                }
            } else if (hdr.ipv6.isValid()) {
                if (hdr.ipv6.hop_limit > 1) {
                    if (!ipv6_host.apply().hit) {
                        ipv6_lpm.apply();
                    }
                    nexthop.apply();
                }
            }

            if (hdr.ipv4.isValid()) {
                hdr.ipv4.ttl =  hdr.ipv4.ttl - ttl_dec;
            } else if (hdr.ipv6.isValid()) {
                hdr.ipv6.hop_limit = hdr.ipv6.hop_limit - ttl_dec;
            }
        }
        
        /* Mirroring */
        port_acl.apply();
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
    Mirror()   ing_port_mirror;

    apply {
        /* 
         * If there is a mirror request, create a clone. 
         * Note: Mirror() externs emits the provided header, but also
         * appends the ORIGINAL ingress packet after those
         */
        if (ig_dprsr_md.mirror_type == ING_PORT_MIRROR) {
            ing_port_mirror.emit<ing_port_mirror_h>(
                meta.mirror_session,
                {
                    meta.mirror_header_type, meta.mirror_header_info,
#ifndef FLEXIBLE_HEADERS
                    0, /* pad0 */
#endif
                    meta.ingress_port,
#ifndef FLEXIBLE_HEADERS
                    0, /* pad1 */
#endif
                    meta.mirror_session,
                    meta.ingress_mac_tstamp, meta.ingress_global_tstamp
                });
        }

        /* Update the IPv4 checksum first. Why not in the egress deparser? */
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
        /* Deparse the regular packet with bridge metadata header prepended */
        pkt.emit(hdr);
    }
}


/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/

struct my_egress_headers_t {
    ethernet_h   cpu_ethernet;
    to_cpu_h     to_cpu;
}

    /********  G L O B A L   E G R E S S   M E T A D A T A  *********/

struct my_egress_metadata_t {
    bridge_h           bridge;
    ing_port_mirror_h  ing_port_mirror;
}

    /***********************  P A R S E R  **************************/

parser EgressParser(packet_in        pkt,
    /* User */
    out my_egress_headers_t          hdr,
    out my_egress_metadata_t         meta,
    /* Intrinsic */
    out egress_intrinsic_metadata_t  eg_intr_md)
{
    inthdr_h inthdr;
    
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(eg_intr_md);
        inthdr = pkt.lookahead<inthdr_h>();
           
        transition select(inthdr.header_type, inthdr.header_info) {
            ( HEADER_TYPE_BRIDGE,         _ ) :
                           parse_bridge;
            ( HEADER_TYPE_MIRROR_INGRESS, (header_info_t)ING_PORT_MIRROR ):
                           parse_ing_port_mirror;
            default : reject;
        }
    }

    state parse_bridge {
        pkt.extract(meta.bridge);
        transition accept;
    }

    state parse_ing_port_mirror {
        pkt.extract(meta.ing_port_mirror);
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
    action just_send() {}

    action send_to_cpu() {
        hdr.cpu_ethernet.setValid();
        hdr.cpu_ethernet.dst_addr   = 0xFFFFFFFFFFFF;
        hdr.cpu_ethernet.src_addr   = 0xAAAAAAAAAAAA;
        hdr.cpu_ethernet.ether_type = ETHERTYPE_TO_CPU;

        hdr.to_cpu.setValid();
        hdr.to_cpu.header_type = meta.ing_port_mirror.header_type;
        hdr.to_cpu.header_info = meta.ing_port_mirror.header_info;
        hdr.to_cpu.pad0 = 0;
        hdr.to_cpu.pad1 = 0;
        hdr.to_cpu.mirror_session  = meta.ing_port_mirror.mirror_session;
        hdr.to_cpu.ingress_port    = meta.ing_port_mirror.ingress_port;

        /* Packet length adjustement since it had headers prepended */
        hdr.to_cpu.pkt_length      = eg_intr_md.pkt_length -
                                   (bit<16>)sizeInBytes(meta.ing_port_mirror);

        /* Timestamps */
        hdr.to_cpu.ingress_mac_tstamp    = meta.ing_port_mirror.
                                                    ingress_mac_tstamp;
        hdr.to_cpu.ingress_global_tstamp = meta.ing_port_mirror.
                                                    ingress_global_tstamp;
        hdr.to_cpu.egress_global_tstamp  = eg_prsr_md.global_tstamp; 
    }

    table mirror_dest {
        key = {
            meta.ing_port_mirror.mirror_session : exact;
        }
        
        actions = {
            just_send;
            send_to_cpu;
        }
        default_action = just_send();
    }
    
    apply {
        if (meta.ing_port_mirror.isValid()) {
            mirror_dest.apply();
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
