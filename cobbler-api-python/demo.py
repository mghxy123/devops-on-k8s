#!/usr/bin/env python
# -*- coding: utf-8 -*-
# File : t1.py
# Author: HuXianyong
# Date : 2022/8/16


#!/usr/bin/python3.6


import xmlrpc.client

server = 'http://192.168.100.52/cobbler_api'
user = 'admin'
password = '123456'

if __name__ == '__main__':

    try:
        remote_server = xmlrpc.client.Server(server)
        token = remote_server.login(user, password)

        print(remote_server.ping())  # cobbler服务器状态监测

        print(remote_server.find_distro())
        print(remote_server.find_system())

        # 创建
        system_id = remote_server.new_system(token)
        remote_server.modify_system(system_id, "name", "web1", token)
        remote_server.modify_system(system_id, "hostname", "web1", token)
        remote_server.modify_system(system_id, 'modify_interface', {
            "macaddress-eth0": "00:0C:29:e1:8a:5b",
            "ipaddress-eth0": "192.168.100.150",
            "Gateway-eth0": "192.168.100.2",
            "subnet-eth0": "255.255.255.0",
            "static-eth0": 1,
            "dnsname-eth0": "192.168.100.2"
        }, token)
        remote_server.modify_system(system_id, "profile", "CentOS-7.4-x86_64", token)
        remote_server.save_system(system_id, token)
        remote_server.sync(token)

        print(remote_server.get_systems())

        ##删除
        remote_server.remove_system("web1", token)
        remote_server.sync(token)
        print(remote_server.find_system())





    except Exception as e:
        exit('URL:%s no access' % server)

    # print(remote_server.get_user_from_token(token))  # 返回cobbler系统登录账号
    # print(remote_server.get_item('distro','Centos6.9-x86_64')) # 获取指定发布版本的信息
    # print('-------------------------')
    # print(remote_server.get_distro('Centos6.9-x86_64'))  #返回distro指定名称的详细信息
    # print('-------------------------')
    # print(remote_server.get_profile('CT6.8_PHY_db_high'))  # 返回profile 指定名称的详细信息
    # print('-------------------------')
    # print(remote_server.get_distros())   # 返回所有distro 的已有内容
    # print('-------------------------')
    # print(remote_server.get_profiles())  # 返回所有profiles的已有内容
    # print('-------------------------')
    # print(remote_server.find_system())  # 以列表返回所有的 system 名称
    # print('-------------------------')
    # print(remote_server.find_distro())  # 以列表返回所有的distro名称
    # print('-------------------------')
    # print(remote_server.find_profile())  # 以列表返回所有profile的名称
    # print('-------------------------')
    # print(remote_server.has_item('distro','Centos6.9-x86_64'))  # 检测指定distro中指定的名称是否存在
    # print('-------------------------')
    # print(remote_server.get_distro_handle('Centos6.9-x86_64',token))  # 没啥用
    # print(remote_server.remove_profile('test111',token))  # 删除指定的profile
    # print('-------------------------')
    # print(remote_server.remove_system('hostname121',token)) # 删除指定的system
    # print('-------------------------')
    # prof_id = remote_server.new_profile(token)  # 创建一个新的profile 并保存
    # print('profile new id:%s' % prof_id)
    # print('-------------------------')
    # remote_server.modify_profile(prof_id,'name','vm_test1',token) # 修改prof_id指定的profile 名称
    # remote_server.modify_profile(prof_id,'distro','centos6.8-x86_64',token)  # 也是修改prof_id的信息
    # remote_server.modify_profile(prof_id,'kickstart','/var/lib/cobbler/kickstarts/txt111',token)
    # remote_server.save_profile(prof_id,token) # 保存
    # remote_server.sync(token) # 同步cobbler修改后的信息，这个做任何操作后，都要必须有
    # print('-------------------------')
    # print(remote_server.get_kickstart_templates())  # 获取所有KS模板文件路径
    # print('-------------------------')
    # print(remote_server.get_snippets())  # 获取所有snippets文件路径
    # print('-------------------------')
    # print(remote_server.is_kickstart_in_use('/var/lib/cobbler/kickstarts/CT6.8_PHY_db_middle.ks')) # 判断ks文件是否在使用
    # print('-------------------------')
    # print(remote_server.generate_kickstart('CT6.8_PHY_web_high')) # 打印profile对应的ks文件内存
    # print('-------------------------')
    # print(remote_server.generate_kickstart('vm_test1','t1'))# 打印profile对应的ks文件内存
    # print('-------------------------')
    # print(remote_server.generate_gpxe('vm_test1')) # 启动方面的，没用
    # print('-------------------------')
    # print(remote_server.generate_bootcfg('vm_test1'))
    # print('-------------------------')
    # print(remote_server.get_blended_data('vm_test1')) # 获取profile 的详细信息
    # print('-------------------------')
    # print(remote_server.get_settings())  # 没啥用
    # print('-------------------------')
    # print(remote_server.get_signatures())  # 不知道输出的是啥
    # print('-------------------------')
    # print(remote_server.get_valid_breeds())  # 获取的是各个操作系统的类型，
    # 输出： ['debian', 'freebsd', 'generic', 'nexenta', 'redhat', 'suse', 'ubuntu', 'unix', 'vmware', 'windows', 'xen']
    # print('-------------------------')
    # print(remote_server.get_valid_os_versions())  # 没啥用
    # print('-------------------------')
    # print(remote_server.get_repo_config_for_profile('vm_test1'))
    # print('-------------------------')
    # print(remote_server.get_repo_config_for_system('t1'))
    # print('-------------------------')
    # print(remote_server.version())  # 返回cobbler版本，没啥用
    # print('-------------------------')
    # print(remote_server.extended_version())  # 返回cobbler详细版本信息，没啥用
    # print('-------------------------')
    # print(remote_server.logout(token))  # 退出当前cobbler连接
    # print('-------------------------')
    # print(remote_server.token_check(token))  # 检测当前token状态，是否失效
    # print('-------------------------')
    # print(remote_server.sync_dhcp(token)  # 同步DHCP
    # print('-------------------------')
    # print(remote_server.sync(token))  # 进行同步更新
    # print('-------------------------')
    # print(remote_server.read_or_write_kickstart_template('cobbler上ks文件路径','false为可写','将要替换ks文件的内容',token))  # 注意 替换KS字符串如果为-1，将删除此Ks文件，条件是此ks文件已不在引用
    # print(remote_server.read_or_write_kickstart_template('/var/lib/cobbler/kickstarts/hostname106.ks',False,-1,token))
    # print('-------------------------')
    # print(remote_server.get_config_data('zhaoyong'))  # 没啥用
    # print('-------------------------')
    # x  = remote_server.test_xmlrpc_ro()
    # print(x.distro)
    # print(remote_server.read_or_write_snippet('/var/lib/cobbler/snippets/test1',False,'zhaoyong_test',token)) # 在snippgets下建立脚本文件
    # distro_obj = cbl_distro.cobbler_distro(remote_server,token)
    # # distro 查询
    # out = distro_obj.find_distro_name()
    # print(out)
    # out = distro_obj.find_distro_info('Centos6.9-x86_64')
    # print(out)
    #
    # profile_obj = cbl_profile.cobbler_profiles(remote_server,token)
    #  profile 查找
    # pro_name_list = profile_obj.find_profile_name()
    # print(out)
    # out = profile_obj.find_profile_info('CT6.8_VM_web_custom')
    # print(out)
    #
    # system_obj = cbl_system.cobbler_system(remote_server,token)
    # # system 查询
    # out_all = system_obj.find_system_name()
    # print(out_all)
    # out = system_obj.system_name_info('tttttt')
    # print(out)
    # del system
