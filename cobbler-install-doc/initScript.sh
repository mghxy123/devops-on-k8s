cat > /var/ftp/pub/initsystem.sh<<'AEOF'
#!/bin/sh
# data: 20220225
# auth: hxy


# 配置yum源
make_yum(){
sed -i.bak \
    -e 's|^mirrorlist=|#mirrorlist=|g' \
    -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.tuna.tsinghua.edu.cn|g' \
    /etc/yum.repos.d/CentOS-*.repo
    
    #update the system
    yum clean all && yum makecache faste

    sleep 1
    
    # 清华源有epel，可以直接安装
    yum install epel-release -y
    sed -i.bak \
    -e 's!^metalink=!#metalink=!g' \
    -e 's!^#baseurl=!baseurl=!g' \
    -e 's!//download\.fedoraproject\.org/pub!//mirrors.tuna.tsinghua.edu.cn!g' \
    -e 's!http://mirrors!https://mirrors!g' \
    /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-testing.repo
        
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
net.ipv4.ip_forward = 0
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

#新增用户
add_user(){
    useradd aizbx
    echo 'aiLab@2021'| passwd --stdin aizbx
    sed -i '101aaizbx     ALL=(ALL)    NOPASSWD: ALL' /etc/sudoers
}

add_baseServer(){
    # 安装必要支持工具及软件工具
    serverList="vim git kexec-tools redhat-lsb net-tools bash-completion chrony dos2unix lrzsz sysstat tree git unzip gcc gcc-c++ koan"
    for server in $serverList
        do
            yum install $server -y
        done
}

add_nginx(){
    yum install nginx -y
    systemctl enable --now nginx
    cp /usr/share/nginx/html/index.html{,.bak}
    echo '<h1>hello ailabe</h1>' >/usr/share/nginx/html/index.html
}

install_docker(){
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum install docker-ce-20.10.6 -y
}

main(){
    make_yum
    make_ntp
    set_limits
    set_kernel
    set_servers
    update_profile
    add_user
    # add_baseServer
    # add_nginx
    install_docker
}
main
AEOF