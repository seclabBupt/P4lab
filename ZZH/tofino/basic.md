- 交换机配置

```shell
bfshell> ucli
bf-sde> pm
bf-sde.pm> port-add 1/- 10G NONE
bf-sde.pm> an-set 1/- 2
bf-sde.pm> port-enb 1/-
bf-sde.pm> port-add 2/- 10G NONE
bf-sde.pm> an-set 2/- 2
bf-sde.pm> port-enb 2/-
bf-sde.pm> show
-----+----+---+----+-------+----+--+--+---+---+---+--------+----------------+----------------+-
PORT |MAC |D_P|P/PT|SPEED  |FEC |AN|KR|RDY|ADM|OPR|LPBK    |FRAMES RX       |FRAMES TX       |E
-----+----+---+----+-------+----+--+--+---+---+---+--------+----------------+----------------+-
1/0  |23/0|132|3/ 4|10G    |NONE|Ds|Au|YES|ENB|DWN|  NONE  |               0|               0|
1/1  |23/1|133|3/ 5|10G    |NONE|Ds|Au|YES|ENB|UP |  NONE  |               0|               0|
1/2  |23/2|134|3/ 6|10G    |NONE|Ds|Au|YES|ENB|UP |  NONE  |               0|               0|
1/3  |23/3|135|3/ 7|10G    |NONE|Ds|Au|YES|ENB|DWN|  NONE  |               0|               0|
2/0  |22/0|140|3/12|10G    |NONE|Ds|Au|YES|ENB|UP |  NONE  |               0|               0|
2/1  |22/1|141|3/13|10G    |NONE|Ds|Au|YES|ENB|UP |  NONE  |               0|               0|
2/2  |22/2|142|3/14|10G    |NONE|Ds|Au|YES|ENB|UP |  NONE  |               0|               0|
2/3  |22/3|143|3/15|10G    |NONE|Ds|Au|YES|ENB|UP |  NONE  |               3|               0|

bf-sde.bf_pltfm.chss_mgmt> port_mac_get 1 0
Port/channel:1/0  Port Mac addr: f8:8e:a1:ec:f9:b5
bf-sde.bf_pltfm.chss_mgmt> port_mac_get 1 1
Port/channel:1/1  Port Mac addr: f8:8e:a1:ec:f9:b6
bf-sde.bf_pltfm.chss_mgmt> port_mac_get 1 2
Port/channel:1/2  Port Mac addr: f8:8e:a1:ec:f9:b7
bf-sde.bf_pltfm.chss_mgmt> port_mac_get 1 3
Port/channel:1/3  Port Mac addr: f8:8e:a1:ec:f9:b8
bf-sde.bf_pltfm.chss_mgmt> port_mac_get 2 0
Port/channel:2/0  Port Mac addr: f8:8e:a1:ec:f9:b9
bf-sde.bf_pltfm.chss_mgmt> port_mac_get 2 1
Port/channel:2/1  Port Mac addr: f8:8e:a1:ec:f9:ba
bf-sde.bf_pltfm.chss_mgmt> port_mac_get 2 2
Port/channel:2/2  Port Mac addr: f8:8e:a1:ec:f9:bb
bf-sde.bf_pltfm.chss_mgmt> port_mac_get 2 3
Port/channel:2/3  Port Mac addr: f8:8e:a1:ec:f9:bc
```

- 服务器配置

```shell
203.207.106.7 ens4f0连接2/2 142 ens4f1连接2/3 143
7: ens4f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 9c:69:b4:60:d4:54 brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.10/24 brd 192.168.100.255 scope global ens4f0
       valid_lft forever preferred_lft forever
arp
192.168.100.20           ether   f8:8e:a1:ec:f9:bb   CM                    ens4f0

203.207.106.8 ens9f0连接2/0 140 ens9f1连接2/1 141
4: ens9f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 9c:69:b4:60:d4:78 brd ff:ff:ff:ff:ff:ff
    altname enp81s0f0
    inet 192.168.100.20/24 scope global ens7f0
       valid_lft forever preferred_lft forever
arp
192.168.100.10           ether   f8:8e:a1:ec:f9:b9   CM                    ens9f0
```

- 运行程序

```
环境：~/bf-sde-9.3.1中的set_sde.bash
编译：~/bf-sde-9.3.1/p4_doc_internal-master/tools中的p4_build.sh
启动：~/bf-sde-9.3.1中的run_switchd.sh
命令行：~/bf-sde-9.3.1中的run_bfshell.sh
添加表项：bfshell> bfrt_python set_up.py
```
