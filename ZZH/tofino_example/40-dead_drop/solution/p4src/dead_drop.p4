/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
const bit<16> ETHERTYPE_TPID = 0x8100;
const bit<16> ETHERTYPE_IPV4 = 0x0800;
const bit<16> ETHERTYPE_DEAD = 0xDEAD;

/* Table Sizes */
const int IPV4_HOST_SIZE = 65536;

#ifdef USE_ALPM
const int IPV4_LPM_SIZE  = 122880;
#else
const int IPV4_LPM_SIZE  = 12288;
#endif

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

enum bit<16> box_op_t {
    DROPOFF = 0,
    PICKOFF = 1
}

typedef bit<16> box_num_t;
typedef bit<16> dest_t;
typedef bit<32> data_t;

/* Dead Drop Header */
header dead_drop_h {
    box_num_t  box_num;
    box_op_t   box_op;
    dest_t     data_dest;
    data_t     box_data;
}


/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    ethernet_h   ethernet;
    vlan_tag_h   vlan_tag;
    dead_drop_h  dead_drop;
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
            ETHERTYPE_DEAD:  parse_dead_drop;
            default: accept;
        }
    }

    state parse_vlan_tag {
        pkt.extract(hdr.vlan_tag);
        transition select(hdr.vlan_tag.ether_type) {
            ETHERTYPE_IPV4:  parse_ipv4;
            ETHERTYPE_DEAD:  parse_dead_drop;
            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition accept;
    }

    state parse_dead_drop {
        pkt.extract(hdr.dead_drop);
        transition accept;
    }
}

    /***************** M A T C H - A C T I O N  *********************/
control DeadDrop(
    inout dead_drop_h dead_drop,
    inout PortId_t    dest,
    inout bit<3>      drop_ctl)
    (bit<32>          num_boxes)
{
    Register<data_t, box_num_t>(num_boxes) data_storage;
    
    RegisterAction<data_t, box_num_t, data_t>(data_storage)
    leave_data = {
        void apply(inout data_t register_data) {
            register_data = dead_drop.box_data;
        }
    };
    
    RegisterAction<data_t, box_num_t, data_t>(data_storage)
    pickup_data = {
        void apply(inout data_t register_data, out data_t result) {
            result = register_data;
            register_data = 0xc01df00d;
        }
    };
    
    Register<dest_t, box_num_t>(num_boxes) dest_storage;
    
    RegisterAction<dest_t, box_num_t, dest_t>(dest_storage)
    store_dest = {
        void apply(inout dest_t register_data) {
            register_data = dead_drop.data_dest;
        }
    };
    RegisterAction<dest_t, box_num_t, dest_t>(dest_storage)
    get_dest = {
        void apply(inout dest_t register_data, out dest_t result) {
            result = register_data;
            register_data = 511;
        }
    };
    
    apply {
        if (dead_drop.isValid()) {
            if (dead_drop.box_op == box_op_t.DROPOFF) {
                leave_data.execute(dead_drop.box_num);
                store_dest.execute(dead_drop.box_num);
                drop_ctl = 1;
                exit;
            } else {
                dead_drop.box_data = pickup_data.execute(dead_drop.box_num);
                dest = (PortId_t)get_dest.execute(dead_drop.box_num);
                drop_ctl = 0;
            exit;
            }
        }
    }
}
    
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
        ig_tm_md.bypass_egress     = 1;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table ipv4_host {
        key = { hdr.ipv4.dst_addr : exact; }
        actions = {
            send; drop;
#ifdef ONE_STAGE
            @defaultonly NoAction;
#endif /* ONE_STAGE */
        }
        
#ifdef ONE_STAGE
        const default_action = NoAction();
#endif /* ONE_STAGE */

        size = IPV4_HOST_SIZE;
    }

#ifdef USE_ALPM
    @alpm(1)
    @alpm_partitions(2048)
#endif    
    table ipv4_lpm {
        key     = { hdr.ipv4.dst_addr : lpm; }
        actions = { send; drop; }
        
        default_action = send(64);
        size           = IPV4_LPM_SIZE;
    }

    DeadDrop(num_boxes=65536) dead_drop;
    apply {
        if (hdr.ipv4.isValid()) {
            if (!ipv4_host.apply().hit) {
                ipv4_lpm.apply();
            }
        }
        
        dead_drop.apply(
            hdr.dead_drop,
            ig_tm_md.ucast_egress_port,
            ig_dprsr_md.drop_ctl);
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
