# cobbler的安装和api接口调用

在安装cobbler完成之后使用，可以直接使用API接口来对cobbler批量装机的进行操作



# 一、服务介绍

1. 这个服务是根据cobbler+flask开发的一套可视化批量服务器安装系统的服务，
2. 其中的功能包括了
   1. 批量安装系统，
   2. 批量重装系统，
   3. 根据不同的业务需求安装不同的服务的应用
   4. 查看cobbler系统安装记录
   5. 查看所有cobbler的系统配置文件等

# 二、服务应用

### 一、相关设置

1. 在config文件中写入cobbler的IP和cobbler 的账号密码，如下:

   ```python
   class Settings:
       cob_ip = '10.0.0.80'
       # cob_ip = '10.110.158.2'
       cob_user = 'cobbler'
       cob_passwd = 'cobbler'
   ```

   

### 二、运行程序

1. 运行cobbler_oprator_web.py开启cobbler操作界面

   即可对cobbler进行操作了

![image-20240306171217576](README.assets\image-20240306171217576.png)

###  三、本系统可以进行如下操作

##### 1、上传所有需要安装的服务器信息列表，

- 然后对上传的服务器进行系统安装
- 其中最主要的就是服务器的新**IP和Mac**地址，重装系统只会关注mac，装好了之后需要新的IP来进行连接
- ![image-20240306171524329](D:\desktop\operations\无人值守安装系统\cobbler\README.assets\image-20240306171524329.png)

#### 2、查看所有的system记录和删除system记录

![image-20240306172244442](README.assets\image-20240306172244442.png)

#### 3、查看所有的distros记录

![image-20240306172532963](README.assets\image-20240306172532963.png)

#### 4、查看所有的profiles记录

![image-20240306172347427](README.assets\image-20240306172347427.png)

#### 4、查看所有的cobbler安装记录

![image-20240306172416336](README.assets\image-20240306172416336.png)