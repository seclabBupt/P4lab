control c_add_queue_delay(inout headers hdr, inout standard_metadata_t standard_metadata) {
    apply {
        if (hdr.ipv4.totalLen > 16w500) {//数据报大于500字节
            if (hdr.queue_delay.isValid()) {
                hdr.queue_delay.delay = standard_metadata.deq_timedelta; //数据包在队列中花费的时间（以微秒为单位）
            }
        }
    }
}
