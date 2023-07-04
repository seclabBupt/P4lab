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
    bool port_is_tagged = false;
    bool port_is_member = false;
    
    action drop() {
        eg_dprsr_md.drop_ctl = 1;
    }

    action send_tagged() {
        port_is_member = true;
        port_is_tagged = true;
    }

    action send_untagged() {
        port_is_member = true;
        port_is_tagged = false;
    }

    table egr_vlan_port {
        key = {
            meta.vid                    : exact;
            eg_intr_md.egress_port[6:0] : exact @name("egress_port");
        }
        actions = {
            send_tagged;
            send_untagged;
            @defaultonly NoAction;
        }
        const default_action = NoAction(); /* is member will be false */
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
    
    table egr_port_vlan_action {
        key = {
            port_is_member : exact; /* ternary is also acceptable */
            port_is_tagged : exact; /* ternary is also acceptable */
        }
        actions = {
            drop; add_vlan_tag; remove_vlan_tag; 
        }
        const entries = {
            {false, false} : drop();
            {false, false} : drop();
            {true,  false} : remove_vlan_tag();
            {true,  false} : add_vlan_tag();
        }
        size = 4;
    }    
           
    apply {       
#ifdef P4_SOURCE_PRUNING
        if (meta.ingress_port == eg_intr_md.egress_port) {
            drop();
        }
#endif
        
        egr_vlan_port.apply();
        egr_port_vlan_action.apply();
    }
}
