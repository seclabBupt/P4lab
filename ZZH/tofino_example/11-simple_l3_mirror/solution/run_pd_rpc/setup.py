#
# Simple mirror session setup script
#

clear_all()


print("Mirror destination 5 -- sending to CPU port") 
mirror.session_create(
    mirror.MirrorSessionInfo_t(
        mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
        direction=mirror.Direction_e.PD_DIR_BOTH,
        mir_id=5,
        egr_port=64, egr_port_v=True,
        max_pkt_len=16384))

print("Mirror Destination 7 -- sending to port 3")
mirror.session_create(
    mirror.MirrorSessionInfo_t(
        mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
        direction=mirror.Direction_e.PD_DIR_BOTH,
        mir_id=7,
        egr_port=3, egr_port_v=True,
        max_pkt_len=16384))

print("Mirror Destination 9 -- sending to port 5, truncating to 100 bytes")
mirror.session_create(
    mirror.MirrorSessionInfo_t(
        mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
        direction=mirror.Direction_e.PD_DIR_BOTH,
        mir_id=9,
        egr_port=5, egr_port_v=True,
        max_pkt_len=100))

conn_mgr.complete_operations()
