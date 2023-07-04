/* -*- P4_16 -*- */

/* This module implements the Egress Control and specifically VLAN check and
 * encapsulation using a single table with 3 actions.
 */
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
    action drop() {
        eg_dprsr_md.drop_ctl = eg_dprsr_md.drop_ctl | 1;
    }

    action send_tagged() {
        hdr.vlan_tag.setValid();
        hdr.vlan_tag.tpid = (bit<16>)ether_type_t.TPID;
#ifdef P4C_1719_FIXED
        hdr.vlan_tag.pcp  = meta.pcp;
        hdr.vlan_tag.dei  = meta.dei;
#else
        hdr.vlan_tag.pcp  = 0;
        hdr.vlan_tag.dei  = 0;
#endif
        hdr.vlan_tag.vid  = meta.vid;
    }
    
    action send_untagged() {
        hdr.vlan_tag.setInvalid();
    }

    action not_a_member() {
        drop();
    }
    
    table egr_vlan_port {
        key = {
            meta.vid                    : exact;
            eg_intr_md.egress_port[6:0] : exact @name("egress_port");
        }
        actions = {
            send_tagged;
            send_untagged;
            not_a_member;
        }
        default_action = not_a_member();
        size = VLAN_PORT_TABLE_SIZE;
    }
    
    apply {       
#ifdef P4_SOURCE_PRUNING
        if (meta.ingress_port == eg_intr_md.egress_port) {
            drop();
        } else {
#endif
            egr_vlan_port.apply();
#ifdef P4_SOURCE_PRUNING
        }
#endif
    }
}    
