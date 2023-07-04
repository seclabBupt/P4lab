/* -*- P4_16 -*- */

/* This module implements the Egress Control and specifically VLAN check
 * by using two indirect registers. Each of them is a two-dimensional array
 * indexed by egress_port[6:0] and VLAN ID. The first register contains 
 * the membership bits and the other one contains the indication of whether
 * a given port is tagged or untagged in a VLAN. 
 * 
 * An if() statement (can also be a 4-entry table) matches these bits in
 * order to decide what to do with the packet
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
    /* In SDE-9.0.0 this needs to be compiled with -Xp4c="--use-pa-solitary" */
    @pa_solitary("egress", "port_is_member_0")
    bit<1> port_is_member;
    @pa_solitary("egress", "port_is_tagged_0")
    bit<1> port_is_tagged;
    
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

    Register<bit<1>, bit<(12+7)>>(1<<(12+7), 0) port_vlan_member;
    RegisterAction<bit<1>, bit<(12+7)>, bit<1>>(port_vlan_member)
    get_membership = {
        void apply(inout bit<1> register_data, out bit<1> is_member) {
            is_member = register_data;
        }
    };
    
    Register<bit<1>, bit<(12+7)>>(1<<(12+7), 0) port_vlan_tagged;
    RegisterAction<bit<1>, bit<(12+7)>, bit<1>>(port_vlan_tagged)
    get_taggedness = {
        void apply(inout bit<1> register_data, out bit<1> is_member) {
            is_member = register_data;
        }
    };

    table egr_port_vlan_action {
        key = {
            port_is_member : exact; /* ternary is also acceptable */
            port_is_tagged : exact; /* ternary is also acceptable */
        }
        actions = {
            send_tagged; send_untagged; not_a_member;
        }
        const entries = {
            {0, 0} : not_a_member();
            {0, 1} : not_a_member();
            {1, 0} : send_untagged();
            {1, 1} : send_tagged();
        }
        size = 4;
    }    
           
    apply {       
#ifdef P4_SOURCE_PRUNING
        if (meta.ingress_port == eg_intr_md.egress_port) {
            drop();
        } else {
#endif
            port_is_member = get_membership.execute(
                eg_intr_md.egress_port[6:0] ++ meta.vid);
            port_is_tagged = get_taggedness.execute(
                 eg_intr_md.egress_port[6:0] ++ meta.vid);
            egr_port_vlan_action.apply();
            
#ifdef P4_SOURCE_PRUNING
        }
#endif
    }
}    
