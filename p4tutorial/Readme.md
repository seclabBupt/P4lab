# p4 相关

相关教程：

- https://github.com/nsg-ethz/p4-learning （主要）

- https://github.com/p4lang （次要）
- https://google.com （中文社区质量较低，一般不容易搜到解决方案）



## 1. p4 环境安装


**OS**：ubuntu 20.04.4

**depends：**

- **PI** ：p4runtime api，网络拓扑中有p4交换机时，必须安装该模块；
- **BMv2**： p4交换机虚拟机 ；
- **P4C**：p4程序编译器，支持p4_14 & p4_16；
- **Mininet**：基于namespace的linux网络仿真软件，对外提供python api；
- **FRRouting** ：网络协议栈仿真软件；
- **P4-Utils**：

PI、BMv2需要编译安装，有一定的安装难度。

P4C、Mininet、FRRouting支持用包管理器安装，非常容易操作。



### 1.1 PI 安装

> 建议每一个模块都在home路径下新建一个文件夹存放文件。
>
> PI部分安装较为繁琐，如有特殊报错需根据本地具体环境进行查阅

#### 1.1.1 子模块安装

##### 1.1.1.1 无需编译模块

```bash
apt install libreadline-dev valgrind libtool-bin libboost-dev libboost-system-dev libboost-thread-dev
```



##### 1.1.1.2 prtobuf v3.18.1

> https://github.com/p4lang/PI 	*protbuf部分*

- 安装步骤：

```bash
cd #回到home
git clone --depth=1 -b v3.18.1 https://github.com/google/protobuf.git
cd protobuf/
./autogen.sh
./configure
make
[sudo] make install
[sudo] ldconfig
```



##### 1.1.1.3 gRPC v1.43.2

> https://github.com/p4lang/PI 	*grpc部分*

- 安装步骤：

```shell
apt-get install build-essential autoconf libtool pkg-config
apt-get install cmake
apt-get install clang libc++-dev
apt-get install zlib1g-dev

cd #回到home
git clone --depth=1 -b v1.43.2 https://github.com/google/grpc.git 
cd grpc
git submodule update --init --recursive 
mkdir -p cmake/build
cd cmake/build
cmake ../..
make
make install
ldconfig
```

- 可能出现的问题：

  1. `git submodule update --init --recursive` 失败

     网络原因，一直重复直到全部成功（比较费事间，建议同步执行 1.1.1.4 bmv2及其依赖），也可以将github中的grpc库clone到gitee，再从gitee clone；*（Also appended in our todo lists）*
     
  1. 按照https://github.com/p4lang/PI grpc部分安装会提示不支持make编译，建议用cmake
  
     参考上述安装步骤即可；



##### 1.1.1.4 bmv2依赖

> https://github.com/p4lang/behavioral-model/blob/main/README.md

- 安装步骤：

```bash
cd #回到home
git clone https://github.com/p4lang/behavioral-model.git

sudo apt-get install -y automake cmake libgmp-dev \
    libpcap-dev libboost-dev libboost-test-dev libboost-program-options-dev \
    libboost-system-dev libboost-filesystem-dev libboost-thread-dev \
    libevent-dev libtool flex bison pkg-config g++ libssl-dev
    
cd ci
[sudo] chmod +x install-*
[sudo]./install-nanomsg.sh
[sudo]./install-thrift.sh

./autogen.sh
./configure
make
[sudo] make install   # if you need to install bmv2
```

- 可能出现的问题：

  1. `git clone https://github.com/p4lang/behavioral-model.git`失败

     网络问题，重复执行git clone直到成功。



##### 1.1.1.4 sysrepo
###### 1.1.1.4.1 子模块 libyang 编译安装

> https://github.com/CESNET/libyang

- 步骤

```bash
 cd #回到home
 git clone --depth=1 -b v0.16-r1 https://github.com/CESNET/libyang.git
  cd libyang
  mkdir build
  cd build
  cmake ..
  make
  make install
```
- 可能出现的问题：
  1. 缺少 pcre：

	```bash
	sudo apt-get update
	sudo apt-get install libpcre3 libpcre3-dev
	# or
	sudo apt-get install openssl libssl-dev
	```


###### 1.1.1.4.2 本体编译安装
> https://github.com/p4lang/PI/blob/main/proto/README.md

- 安装步骤：

```bash
cd #回到home
git clone --depth=1 -b v0.7.5 https://github.com/sysrepo/sysrepo.git
cd sysrepo
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_EXAMPLES=Off -DCALL_TARGET_BINS_DIRECTLY=Off ..
make
[sudo] make install
```

- 可能会出现的问题：

  1. 该部分可能出现的问题很多，主要集中在执行`cmake -DCMAKE...`阶段，会出现缺少库的问题

     解决方法，如报错缺少xxx，执行`apt install xxx`；

     如果报错提示无法定位到xxx库，执行`apt install libxxx-dev；`

     如果仍然找不到该库，百度&google搜ubuntu安装xxx；

     直到cmake成功



#### 1.1.2 pi 编译安装

> https://github.com/p4lang/PI

- 安装步骤

```bash
cd #回到home

git clone https://github.com/p4lang/PI.git
git submodule update --init --recursive
./autogen.sh
./configure --with-proto --with-bmv2 --with-cli
make
make check
[sudo] make install
```

- 可能出现的问题

  1. 编译时报错缺少xxx头文件

     解决方法同1.1.1.4.2 sysrepo部分；

  2. 执行`git submodule update --init --recursive` 比较费时间，建议同步安装p4c或者mininet



### 1.2.1 bmv2 安装

如在1.1.1.4 bmv2依赖 部分执行了`[sudo] make install` 那么该部分可以跳过，否则返回 1.1.1.4 bmv2依赖 部分执行相关操作。



### 1.2.2 P4C 安装

> https://github.com/p4lang/p4c

- 安装步骤

```bash
sudo apt-get install cmake g++ git automake libtool libgc-dev bison flex \
libfl-dev libgmp-dev libboost-dev libboost-iostreams-dev \
libboost-graph-dev llvm pkg-config python3 python3-pip \
tcpdump

pip3 install ipaddr scapy ply
sudo apt-get install -y doxygen graphviz texlive-full

. /etc/os-release
echo "deb http://download.opensuse.org/repositories/home:/p4lang/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/home:p4lang.list
curl -L "http://download.opensuse.org/repositories/home:/p4lang/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
sudo apt-get update
sudo apt install p4lang-p4c
```

- 可能出现的问题
  1. `sudo apt-get install -y doxygen graphviz texlive-full` 非常费时间，建议同步安装mininet



### 1.2.3 mininet 安装

```bash
sudo apt install mininet
```



### 1.2.4 FRRouting 安装

> https://deb.frrouting.org

- 安装步骤：

```bash
# add GPG key
curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -

# possible values for FRRVER: frr-6 frr-7 frr-8 frr-stable
# frr-stable will be the latest official stable release
FRRVER="frr-stable"
echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | sudo tee -a /etc/apt/sources.list.d/frr.list

# update and install FRR
sudo apt update && sudo apt install frr frr-pythontools
```

- 可能出现的问题

  1. apt update报错

     删除`/etc/apt/sources.list.d/frr.list`，执行`sudo apt update && sudo apt install frr frr-pythontools`



### 1.2.5 p4-utils

> https://github.com/nsg-ethz/p4-utils

- 安装步骤：

```bash
cd #回到home
git clone https://github.com/nsg-ethz/p4-utils.git
cd p4-utils
sudo ./install.sh

cd
git clone https://github.com/mininet/mininet mininet
cd mininet
# Build mininet
sudo PYTHON=python3 ./util/install.sh -nwv

apt-get install bridge-utils
```

- 可能遇到的问题：
  1. `./install.sh` 部分报错缺少xxx库，参考1.1.1.4.2 sysrepo部分；







## 2 运行时出现的BUG

> Under maintenance……



### 1. 无法调用xterm

- 报错：

> xterm: Xt error: Can't open display: %s
> xterm: DISPLAY is not set



- **原因**：https://github.com/mininet/mininet/wiki/FAQ#x11-forwarding

> 没有正确开启**X11 forwarding**



- **MAC OS X 解决方法**：https://zhuanlan.zhihu.com/p/265207166（下载XQuartz）

```zsh
$ brew install XQuartz
$ XQuartz
$ export DISPLAY=:0

$ ssh -Y root@xxx.xxx.xxx.xxx

#连接linux服务器端
$ xterm
```
