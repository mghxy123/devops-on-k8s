#!/usr/bin/env python
# -*- coding: utf-8 -*-
# File : cobblerApi.py
# Author: HuXianyong
# Date : 2022/7/26
import time

import xlrd
from cobApi import CobblerAPI
cob_api = CobblerAPI()

# class CobOperator:
#     def __init__(self):
#         excel_name =

def cob_operator():
    xd = xlrd.open_workbook('第二批搬迁机器.xlsx')
    table = xd.sheet_by_index(0)


    list1 = []
    cobbler_system_info = {}


    systems_list = cob_api.cobbler_query_system_list()

    for cols_info in range(1,table.nrows):
        new_ip_eno1 = table.row(cols_info)[8].value
        rack = table.row(cols_info)[9].value
        eno1_mac = table.row(cols_info)[14].value
        execl_data = {}
        # old_ip_eno1 = int(table.row(cols_info)[0].value)
        # role = table.row(cols_info)[1].value
        # mechanic_type = table.row(cols_info)[2].value
        # gpu_type = table.row(cols_info)[3].value
        #
        # # hostname = table.row(cols_info)[10].value
        # localnic_ip = table.row(cols_info)[11].value
        # nfs_mount_ip = table.row(cols_info)[13].value
        #
        # localnic_mac = table.row(cols_info)[15].value

        list1.append(execl_data)

        if new_ip_eno1 not in systems_list:

            last_ip = new_ip_eno1.rsplit('.')[3]
            cobbler_system_info['name'] = new_ip_eno1
            cobbler_system_info['hostname'] = '{0}-gpu{0}-{1}'.format(last_ip.zfill(3),rack.split('.')[0])
            cobbler_system_info['netCardName'] = 'eno1'
            cobbler_system_info['macaddress'] = eno1_mac
            cobbler_system_info['ipaddress'] = new_ip_eno1
            cobbler_system_info['Gateway'] = "10.110.159.254"
            cobbler_system_info['subnet'] = "255.255.255.0"
            cobbler_system_info['static'] = 1
            cobbler_system_info['dnsname'] = "10.96.1.18" # 这个用python 的
            cobbler_system_info['profile'] = "centos7-x86_64" # 这个名字不要错，用cobbler profile list 来查询

            # 这三个要用就直接开启就行
            # 新增system信息
            # cob_api.cobbler_system_add(cobbler_system_info)

            # 删除表中的system数据
            # cob_api.cobbler_system_remove(new_ip_eno1)

            # 查询system的详细信息
            # cob_api.cobbler_query_system(new_ip_eno1)
        else:
            print('%s的装机配置已经存在，'%new_ip_eno1)
        # cob_api.cobbler_sync()

if __name__ == '__main__':
    cob_operator()
    cob_api.cobbler_sync()
