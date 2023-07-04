/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
const bit<16> ETHERTYPE_TPID = 0x8100;
const bit<16> ETHERTYPE_IPV4 = 0x0800;
const bit<16> ETHERTYPE_MPLS = 0x8847;

/* Table Sizes */
const int IPV4_HOST_SIZE = 65536;
const int IPV4_LPM_SIZE  = 12288;

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

header mpls_h {
    bit<20> label;
    bit<3> exp;
    bit<1> bos;
    bit<8> ttl;
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    ethernet_h   ethernet;
    vlan_tag_h   vlan_tag;
    mpls_h[5]    mpls;
    ipv4_h       ipv4;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct my_ingress_metadata_t {
}

    /***********************  P A R S E R  **************************/
parser IngressParser(packet_in        pkt,
    /* User */    
    out my_ingress_headers_t          hdr,
    out my_ingress_metadata_t         meta,
    /* Intrinsic */
    out ingress_intrinsic_metadata_t  ig_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
     state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_TPID:  parse_vlan_tag;
            ETHERTYPE_IPV4:  parse_ipv4;
            ETHERTYPE_MPLS:  parse_mpls;
            default: accept;
        }
    }

    state parse_vlan_tag {
        pkt.extract(hdr.vlan_tag);
        transition select(hdr.vlan_tag.ether_type) {
            ETHERTYPE_IPV4:  parse_ipv4;
            ETHERTYPE_MPLS:  parse_mpls;
            default: accept;
        }
    }

    state parse_mpls {
        pkt.extract(hdr.mpls.next);
        transition select(hdr.mpls.last.bos) {
            0: parse_mpls;
            1: accept;
        }
    }
    
    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
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

    action mpls_1_encap(PortId_t port, bit<20> label1) {
        hdr.ethernet.ether_type = ETHERTYPE_MPLS;
        hdr.mpls[0] = { label1, 0, 1, 10 };
        send(port);
    }
    
    action mpls_2_encap(PortId_t port, bit<20> label1, bit<20> label2) {
        hdr.ethernet.ether_type = ETHERTYPE_MPLS;
        hdr.mpls[0] = { label1, 0, 0, 10 };
        hdr.mpls[1] = { label2, 0, 1, 20 };
        send(port);
    }
    
    action mpls_3_encap(PortId_t port, bit<20> label1, bit<20> label2,
                        bit<20> label3) {
        hdr.ethernet.ether_type = ETHERTYPE_MPLS;
        hdr.mpls[0] = { label1, 0, 0, 10 };
        hdr.mpls[1] = { label2, 0, 0, 20 };
        hdr.mpls[2] = { label3, 0, 1, 30 };
        send(port);
    }
    
    action mpls_4_encap(PortId_t port, bit<20> label1, bit<20> label2,
                        bit<20> label3, bit<20> label4 ) {
        hdr.ethernet.ether_type = ETHERTYPE_MPLS;
        hdr.mpls[0] = { label1, 0, 0, 10 };
        hdr.mpls[1] = { label2, 0, 0, 20 };
        hdr.mpls[2] = { label3, 0, 0, 30 };
        hdr.mpls[3] = { label4, 0, 1, 40 };
        send(port);
    }
    
    action mpls_5_encap(PortId_t port, bit<20> label1, bit<20> label2,
                        bit<20> label3, bit<20> label4, bit<20> label5) {
        hdr.ethernet.ether_type = ETHERTYPE_MPLS;
        hdr.mpls[0] = { label1, 0, 0, 10 };
        hdr.mpls[1] = { label2, 0, 0, 20 };
        hdr.mpls[2] = { label3, 0, 0, 30 };
        hdr.mpls[3] = { label4, 0, 0, 40 };
        hdr.mpls[4] = { label5, 0, 1, 50 };
        send(port);
    }

    table ipv4_host {
        key = { hdr.ipv4.dst_addr : exact; }
        actions = {
            send; drop;
            mpls_1_encap; mpls_2_encap; mpls_3_encap;
            mpls_4_encap; mpls_5_encap;
            @defaultonly NoAction;
        }
        const default_action = NoAction();
        size = IPV4_HOST_SIZE;
    }

    @alpm(1)
    @alpm_partitions(2048)
    table ipv4_lpm {
        key     = { hdr.ipv4.dst_addr : lpm; }
        actions = {
            send; drop;
            mpls_1_encap; mpls_2_encap; mpls_3_encap;
            mpls_4_encap; mpls_5_encap;
        }
        
        default_action = send(64);
        size           = IPV4_LPM_SIZE;
    }
    
    apply {
        if (hdr.ipv4.isValid()) {
            if (!ipv4_host.apply().hit) {
                ipv4_lpm.apply();
            }
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
    apply {
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
