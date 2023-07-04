/* -*- P4_16 -*- */

/* Egress Control option 2. A table that produces a boolean and
 * a condition that selects an action, based on it
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
    bool send_egress_tagged = false;
    
    action drop() {
        eg_dprsr_md.drop_ctl = 1;
    }

    action send_tagged() {
        send_egress_tagged = true;
    }

    action send_untagged() {
         send_egress_tagged = false;
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
    
    /* Egress VLAN Encapsulation */
    action add_vlan_tag() {
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
    
    action remove_vlan_tag() {
        hdr.vlan_tag.setInvalid();
    }
    
    apply {       
#ifdef P4_SOURCE_PRUNING
        if (meta.ingress_port == eg_intr_md.egress_port) {
            drop();
        }
#endif
        
        egr_vlan_port.apply();
        if (send_egress_tagged) {
            add_vlan_tag();
        } else {
            remove_vlan_tag();
        }
    }
}
