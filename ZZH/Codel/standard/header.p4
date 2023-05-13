struct routing_metadata_t {
    bit<16> tcpLength;
}

struct codel_t {
    bit<48> drop_time;//0/time_now+CONTROL_INTERVAL  开始丢包时间
    bit<48> time_now;//此刻包出队时的时间戳
    bit<1>  ok_to_drop;//是否丢包
    bit<1>  state_dropping;//是否已经开始丢包
    bit<32> delta;//上一个周期间丢了几个包
    bit<48> time_since_last_dropping;//与上个周期最后一次丢包时间间隔
    bit<48> drop_next;//下一个超过该时刻就丢包
    bit<32> drop_cnt;//记录此周期丢包次数
    bit<32> last_drop_cnt;//上一个周期结束时丢包数
    bit<1>  reset_drop_time;//是否超过target，周期归零
    bit<48> new_drop_time;//起初超过该时刻丢包time_now+CONTROL_INTERVAL
    bit<48> new_drop_time_helper;
    bit<9>  queue_id;
}

header ethernet_t {
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ethertype;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header udp_t {
    bit<16> sourcePort;
    bit<16> destPort;
    bit<16> length_;
    bit<16> checksum;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<8>  flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct headers {
    ethernet_t    ethernet; 
    ipv4_t        ipv4; 
    tcp_t         tcp; 
    udp_t         udp;
}

struct metadata {
    codel_t             codel; 
    routing_metadata_t  routing_metadata;
}
