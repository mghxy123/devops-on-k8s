#!/bin/bash
# 这个版本是针对centos7.9来安装cobbler
# author：hxy
# date：20220321

makeDefault(){
    # 默认网卡
    defaultNetcard='ens34'
    # 默认密码
    defaultPwd='123456'
    
    # 默认IP
    netCardName=$(ip a |grep -E '^[0-9]'|awk -F': ' 'NR==2{print $2}')

    IP=$(ifconfig ${defaultNetcard} |awk '/broadcast/{print $2}')
    
    # 生成salt密码
    saltpwd=$(openssl passwd -1 -salt 'random-phrase-here' ${defaultPwd})
}

installServer(){
    yum -y install cobbler cobbler-web tftp dhcp httpd xinetd pykickstart debmirror fence-agents rsync vsftpd
    if test $(echo $?) -ne 0;then
        echo 'yum install failed exit！'
        exit 5
    fi
}


set_cobbler_conf(){
    # 1、修改服务器IP 2、修改tftp下一跳I、 3、修改默认密码配置 4、修改使用dhcp  5、使用pxe启动一次配置，避免重复安装系统
    sed -ie "s/\(^server:\).*/\1 ${IP}/;\
            s/\(^next_server:\).*/\1 ${IP}/;\
            s@\(default_password_crypted:\).*@\1 \"${saltpwd}\"@;\
            s/manage_dhcp: 0/manage_dhcp: 1/;\
            s/pxe_just_once: 0/pxe_just_once: 1/;\
            " /etc/cobbler/settings 

    # debian 系统需要修改这个，别的不用 ，不关会提示，但是不影响
    sed -ie "s/@arches=\"i386\"/#@arches=\"i386\"/;\
            s/@dists=\"sid\"/#@dists=\"sid\"/" /etc/debmirror.conf

    # 修改DHCP配置模板文件，
    sed -ie "s/192.168.1/${IP%.*}/g;\
            s/${IP%.*}.5/${IP}/;\
            s/${IP%.*}.100/${IP%.*}.200/;\
            s/\$next_server/${IP}/" /etc/cobbler/dhcp.template

    # 把tftp修改为xinetd启动    
    sed -i 's@\(.*disable.*\)= yes@\1= no@' /etc/xinetd.d/tftp 
    
    # 启动服务，并设置开机启动
    systemctl enable --now cobblerd httpd xinetd rsyncd vsftpd dhcpd

    # 检查cobbler配置是否正确
    cobbler check

    # 同步cobbler配置
    cobbler sync
}


make_cdrom(){
    # 挂载光盘
    mkdir /media/cdrom
    mount /dev/cdrom /media/cdrom 2>/dev/null
    if $? -ne 0;then
        echo "mount失败"
        
        if $(df -h |grep -c "/media/cdrom") -eq 1;then
            echo "光盘已挂载"
        else
            echo "光盘挂载失败，退出运行"
            echo 2
        fi
    else
        echo "光盘挂载成功"
    fi
}


make_ftpyum_repo(){
    # 制作FTP yum源
    mkdir /etc/yum.repos.d/bak
    mv  /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/
cat > /etc/yum.repos.d/centos7.repo<<EOF
[centos7]
name=centos7
baseurl=ftp://{{IP}}/centos7
#baseurl=ftp://${IP}/centos7
enable=1
gpgcheck=0
EOF
}



# 镜像文件导入
cobbler import --path=/media/cdrom --name=centos7_computer --arch=x86_64
cobbler import --path=/media/cdrom --name=centos7_control --arch=x86_64
cobbler import --path=/media/cdrom --name=centos7_min --arch=x86_64

# 查看镜像信息
cobbler distro report --name=centos7_min-x86_64
cobbler profile report --name=centos7_min-x86_64
cobbler distro report --name=centos7_computer-x86_64
cobbler profile report --name=centos7_computer-x86_64

# 查看镜像列表
cobbler distro list  

# 配置ks文件
cat >/var/lib/cobbler/kickstarts/centos7_computer.ks<<'EOF'
# Cobbler for Kickstart Configurator for CentOS 7 by clsn
install             #安装系统
url --url=$tree     #url地址为cobbler内置变量
text                #文本方式安装，修改为图形界面则为Graphical
lang en_US.UTF-8    #语言
keyboard us  #键盘
zerombr   #该参数用于清除引导信息，需要让其生效可以在参数后添加yes即可。
bootloader --location=mbr --driveorder=sda --append="crashkernel=auto rhgb quiet"
#指定引导装载程序怎样被安装.对于安装和升级,这个选项都是必需的.
#Network information
$SNIPPET('network_config')  #该参数表示使用下方%pre中的脚本来配置网络，相关脚本存放于/var/lib/cobbler/snippets
#如果不需要脚本配置可启用以下配置
#network --bootproto=dhcp --device=eth0 --onboot=yes --noipv6 --hostname=CentOS7
timezone --utc Asia/Shanghai      #时区
authconfig --enableshadow --passalgo=sha512  #加密shadow
rootpw  --iscrypted $default_password_crypted  #设置root密码
clearpart --all --initlabel   #--all删除所有分区，后者将磁盘标签初始化为缺省值设置。
part /boot --fstype="xfs" --ondisk=sda --size=1024 #boot分区大小
part swap --fstype="swap" --ondisk=sda --size=1024 #swap分区大小
part / --fstype="xfs" --ondisk=sda --size=1 --grow
part /home --fstype="xfs" --ondisk=sdb --size=1 --grow

firstboot --disable      #决定是否在系统第一次引导时启动"设置代理”.禁用
selinux --disabled       #在系统里设置SELinux状态.
firewall --disabled      #在系统狸设置而防火墙状态
logging --level=info     #这个命令控制安装过程中anaconda的错误日志.它对安装好的系统没有影响。
reboot                   #安装后重启
%pre                     #pre中定了前面使用的具体脚本名称。
$SNIPPET('log_ks_pre')
$SNIPPET('kickstart_start')
$SNIPPET('pre_install_network_config')
# Enable installation monitoring
$SNIPPET('pre_anamon')
%end
%packages                #自定义安装内容，这里可以可以自行生成ks文件然后把对应的配置复制到这里。当前配置为最小化安装，以及安装系统常用工具。
$SNIPPET('func_install_if_enabled')
%end
%post                   #安装后执行操作，可以执行脚本也可以直接执行命令。
$SNIPPET('log_ks_post')
# Start yum configuration
$yum_config_stanza
# End yum configuration
$SNIPPET('post_install_kernel_options')
$SNIPPET('post_install_network_config')
$SNIPPET('func_register_if_enabled')
$SNIPPET('download_config_files')
$SNIPPET('koan_environment')
$SNIPPET('redhat_register')
$SNIPPET('cobbler_register')
# Enable post-install boot notification
$SNIPPET('post_anamon')
# Start final steps
$SNIPPET('kickstart_done')
# End final steps
# initsystem
curl -o /tmp/initsystem.sh ftp://{{IP}}/initsystem.sh
/bin/bash /tmp/initsystem.sh
%end
EOF

# 制作ks文件
cp /var/lib/cobbler/kickstarts/sample_end.ks /var/lib/cobbler/kickstarts/centos7_min.ks 
sed -i '30a authconfig --enableshadow --passalgo=sha512' /var/lib/cobbler/kickstarts/centos7_min.ks 

sed -i '35,$d' /var/lib/cobbler/kickstarts/centos7_computer.ks
cp /var/lib/cobbler/kickstarts/centos7_computer.ks /var/lib/cobbler/kickstarts/centos7_control.ks

# 解决中文注释问题
sed  -i 's/#.*//g' /var/lib/cobbler/kickstarts/centos7_*.ks


cat >>/var/lib/cobbler/kickstarts/centos7_computer.ks<<'EOFE'
%packages
@^graphical-server-environment
@base
@compat-libraries
@core
@desktop-debugging
@development
@dial-up
@fonts
@gnome-desktop
@guest-agents
@guest-desktop-agents
@hardware-monitoring
@input-methods
@internet-browser
@java-platform
@multimedia
@performance
@print-client
@remote-system-management
@x11
kexec-tools
%end

%post
# initsystem
curl -o /tmp/initsystem.sh ftp://{{IP}}/pub/initsystem.sh
/bin/bash /tmp/initsystem.sh
%end
EOFE
sed  -i "s/{{IP}}/$IP/g" /var/lib/cobbler/kickstarts/centos7_*.ks

# 指定ks文件位置-cobbler 加载 CentOS-7.ks 配置文件，KS文集不能有中文
# 做两套ks文件，用来展示区别
cobbler profile edit --name=centos7_computer-x86_64 --kickstart=/var/lib/cobbler/kickstarts/centos7_computer.ks  
cobbler profile edit --name=centos7_computer-x86_64 --kickstart=/var/lib/cobbler/kickstarts/centos7_control.ks  
cobbler profile edit --name=centos7_min-x86_64 --kickstart=/var/lib/cobbler/kickstarts/centos7_min.ks  

# 安装后脚本
cat > /var/ftp/initsystem.sh<<'AEOF'
#!/bin/sh
# data: 20220225
# auth: hxy


# 配置yum源
make_yum(){
mkdir /etc/yum.repos.d/repo_bak
mv  /etc/yum.repos.d/*.repo /etc/yum.repos.d/repo_bak

cat > /etc/yum.repos.d/centos7.repo << EOF 
[centos7]
name=centos7
baseurl=ftp://{{IP}}/centos7
enable=1
gpgcheck=0
EOF

    yum makecache faste
}

# 时间同步
make_ntp(){
yum install ntp -y
/usr/sbin/ntpdate cn.pool.ntp.org > /dev/null 2>&1
    
cat >> /var/spool/cron/root << EOF
*/5 * * * * /usr/sbin/ntpdate cn.pool.ntp.org > /dev/null 2>&1
* * * * */1 /usr/sbin/hwclock -w > /dev/null 2>&1
EOF

systemctl restart crond
}


set_limits(){
    if [ ! -f "/etc/security/limits.conf.bak" ]; then
        cp /etc/security/limits.conf /etc/security/limits.conf.bak
    fi

    sed -i "/^*.*soft.*nofile/d" /etc/security/limits.conf
    sed -i "/^*.*hard.*nofile/d" /etc/security/limits.conf
    sed -i "/^*.*soft.*nproc/d" /etc/security/limits.conf
    sed -i "/^*.*hard.*nproc/d" /etc/security/limits.conf
    
cat >> /etc/security/limits.conf << EOF
#---------custom-----------------------
*              -       nproc           102400  
*              -       nofile          102400  
EOF

if [ ! -f "/etc/sysctl.conf.bak" ]; then
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
fi

cat > /etc/sysctl.conf << EOF
#-------custom---------------------------------------------
#
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
kernel.sysrq = 0
kernel.core_uses_pid = 1
net.ipv4.tcp_syncookies = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096    87380   4194304
net.ipv4.tcp_wmem = 4096    16384   4194304
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 262144
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 30
net.ipv4.ip_local_port_range = 1024    65535
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 0
vm.overcommit_memory = 1
vm.panic_on_oom = 0
fs.inotify.max_user_watches = 89100
EOF
}

set_kernel(){
    #buckets
    echo 6000 > /proc/sys/net/ipv4/tcp_max_tw_buckets
     
    #delete
    sed -i "/^kernel.shmmax/d;/^kernel.shmall/d" /etc/sysctl.conf
    #add
    shmmax=`free -l |grep Mem |awk '{printf("%d\n",$2*1024*0.9)}'`
    shmall=$[$shmmax/4]
    echo "kernel.shmmax = "$shmmax >> /etc/sysctl.conf
    echo "kernel.shmall = "$shmall >> /etc/sysctl.conf
    #bridge
    modprobe bridge
    lsmod|grep bridge
    #reload sysctl
    /sbin/sysctl -p
}

set_servers(){
    #disable selinux #关闭SELINUX
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    setenforce 0
    echo -e "\033[31m selinux ok \033[0m"

    # 修改SSH
    sed -i 's/^GSSAPIAuthentication yes$/GSSAPIAuthentication no/' /etc/ssh/sshd_config
    sed -i '/^#UseDNS/s/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
    sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
    #关闭无密码登录
    sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
    /etc/init.d/sshd restart


    #关闭一些没用的服务
    chkconfig bluetooth off > /dev/null 2>&1
    chkconfig cups off  > /dev/null 2>&1
    chkconfig ip6tables off  > /dev/null 2>&1
    chkconfig | grep -E "cups|ip6tables|bluetooth"

    systemctl disable firewalld
    systemctl stop firewalld
}


update_profile(){
cat >> /etc/profile << EOF
#设置core文件的最大值
ulimit -c unlimited
#设置堆栈的最大值
ulimit -s unlimited
#句柄数为102400
ulimit -SHn 102400
EOF
    # PS1
    sed -i "/^PS1=.*/d" /etc/profile
    echo 'export PS1="\[\033[01;36m\]\u\[\033[00m\]@\[\033[01;32m\]\h\[\033[00m\][\[\033[01;33m\]\t\[\033[00m\]]:\[\033[01;34m\]\w\[\033[00m\]\n$ "' >> /etc/bashrc
    source /etc/bashrc
        
    # Record command用户操作行为纪录
    sed -i "/^export PROMPT_COMMAND=.*/d" /root/.bash_profile
    echo "export PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });user=\$(whoami); echo \$(date \"+%Y-%m-%d %H:%M:%S\"):\$user:\`pwd\`/:\$msg ---- \$(who am i); } >> /tmp/\`hostname\`.\`whoami\`.history-timestamp'" >> /root/.bash_profile
         
    # Wrong password five times locked 180s
    sed -i "/^auth        required      pam_tally2.so deny=5 unlock_time=180/d" /etc/pam.d/system-auth
    sed -i '4a auth        required      pam_tally2.so deny=5 unlock_time=180' /etc/pam.d/system-auth
    source /etc/profile
}

add_baseServer(){
    # 安装必要支持工具及软件工具
    serverList="vim git kexec-tools redhat-lsb net-tools bash-completion chrony dos2unix lrzsz sysstat tree unzip gcc gcc-c++ koan elfutils-libelf-devel kernel-devel-uname-r dkms"
    for server in $serverList
        do
            yum install $server -y
        done
}

install_nvidia(){
cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
dracut --force
sleep 2
    wget -O /tmp/nvidia_pkg.tar.gz ftp://{{IP}}/nvidia_pkg.tar.gz
    tar xf /tmp/nvidia_pkg.tar.gz -C /tmp/ && cd /tmp/nvidia_pkg && yum install ./* -y
    \cp /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bak
    dracut /boot/initramfs-$(uname -r).img $(uname -r)
    sleep 2
    wget -O /tmp/NVIDIA-Linux-x86_64-510.47.03.run ftp://{{IP}}/NVIDIA-Linux-x86_64-510.47.03.run
    # 先测试下如果不启动是否可以安装
    # reboot 
    sh /tmp/NVIDIA-Linux-x86_64-510.47.03.run -no-opengl-files --dkms -s
    sleep 2
    nvidia-smi
}

check_nvidia_script(){
chmod 755 /etc/rc.d/rc.local
echo '/tmp/tmp_nvidia.sh >/tmp/test_nvidia' >> /etc/rc.d/rc.local
cat > /tmp/tmp_nvidia.sh<<'EOF'
#!/bin/bash
status=$(nvidia-smi >/dev/null 2>&1 && echo yes || echo no)
if test "$status" == "yes";then
    sed -i '/tmp_nvidia/d' /etc/rc.d/rc.local
else
    sh /tmp/NVIDIA-Linux-x86_64-510.47.03.run -no-opengl-files --dkms -s >/dev/null 2>&1
    sleep 2
    nvidia-smi
fi
echo yes >/tmp/yes
EOF

chmod 755 /tmp/tmp_nvidia.sh
}

install_docker(){
    yum install -y device-mapper-persistent-data lvm2
    wget -O /tmp/docker_pkg.tar.gz ftp://{{IP}}/docker_pkg.tar.gz
    tar xf /tmp/docker_pkg.tar.gz -C /tmp/&& cd /tmp/docker_pkg && yum install ./* -y
    systemctl start docker 
    sleep 2
    docker info >/dev/null 2>&1 && echo 'docker install ok' || echo 'docker install failed'
}

main(){
    make_yum
    make_ntp
    set_limits
    set_kernel
    set_servers
    update_profile
    add_baseServer
    install_docker
    install_nvidia
    check_nvidia_script
}
main
AEOF

sed  -i "s/{{IP}}/$IP/g" /var/ftp/initsystem.sh

# 配置网卡的格式为ethX模式，方便管理
cobbler profile edit --name=centos7_computer-x86_64 --kopts='net.ifnames=0 biosdevname=0'
cobbler profile edit --name=centos7_min-x86_64 --kopts='net.ifnames=0 biosdevname=0'

systemctl restart cobblerd
sleep 2
cobbler sync

# 查看cobbler生成配置
cobbler profile report --name=centos7_min-x86_64 # 最小化安装，未做初始化
cobbler profile report --name=centos7_computer-x86_64 # 定制安装

# cobbler system remove --name cobbler_BG_centos7
# 通过mac配置指定的服务器所安装的固定的镜像，已经设置固定IP、设置主机名等操作
cobbler system add \
--name=centos7_computer \
--mac=00:0C:29:DE:BB:DD \
--profile=centos7_computer-x86_64 \
--ip-address=10.0.0.179 \
--subnet=255.255.255.0 \
--gateway=10.0.0.1 \
--interface=eth1 \
--static=1 \
--hostname=cobbler_BG_centos7

cobbler system add \
--name=centos7_min \
--mac=00:0C:29:DE:DB:EB \
--profile=centos7_min-x86_64 \
--ip-address=192.168.146.222 \
--subnet=255.255.255.0 \
--gateway=192.168.146.2 \
--interface=eth1 \
--static=1 \
--hostname=centos7_min \
--name-servers="114.114.114.114 8.8.8.8"


#cobbler system remove --name cobbler_BG_centos7
# 指定系统ks列表  
cobbler system list
# 客户端重装系统
#koan -r -s 192.168.146.139 -p centos7_computer-x86_64 && reboot

# 虚拟机需要2G以上的内存，不然会提示空间不够
# 目前虚拟机系统安装时间大约需要10分钟左右、物理机待测试
