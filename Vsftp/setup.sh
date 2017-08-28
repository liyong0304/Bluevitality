#!/bin/bash
#仅适用于RPM或YUM安装的Vsftp服务。默认吧随机产生的账号密码输出到当前目录
#默认情况下每个账户的主目录都在/tmp下

#定义变量
userlist=(shangftp wangftp)             #数组形式的账号名（密码默认随机产生，或修改循环中的Password变量）
chroot_dir=/data                        #FTP根路径

[ -d ${chroot_dir} ] ||  { echo -e "\033[31mdirectory not exist!......\033[0m" ; exit 1 ; }

#check user
if [ $(id -u) != "0" ]
then
  echo -e "\033[1;40;31mError: You must be root to run this script, please use root to install this script.\033[0m"
  exit 1
fi

#使用随机的数字密码创建帐号
for username in ${userlist[@]}
do
        if id ${username} 2>&- ; then
                echo -e "\033[31m user ${username} already  exist...\033[0m" 
        else
                Password=${RANDOM}   #需要统一密码的话修改这里
                useradd -d ${chroot_dir:=/tmp}  -M ${username}
                echo $Password | passwd  ${username} --stdin 2>&-
                echo -e "$username \t $Password" >> ./Ftp_Userinfo.txt          #输出账号与其密码到当前目录文件中
                echo -e "\033[32mFTP user create  success...\033[0m"
        fi
done

#查找RPM安装时的配置文件（默认不需要）
config_file=$(awk 'BEGIN{while("rpm -qc vsftpd"|getline)/vsftpd.conf/;print}')

#写入配置文件 (使用时需把注释去掉！否则报语法错误)
cat > ${config_file} <<eof
listen_port=21
connect_from_port_20=YES        #是否用20作为数据传输端口
ftp_data_port=20                #在PORT方式下数据传输端口
pasv_enable=YES                 #是否使用PASV模式；若NO则使用PORT模式。默认YES
pasv_max_port=0                 #在PASV模式下数据连接可使用的端口范围的最大端口，0：任意端口
pasv_min_port=0                 #在PASV模式下数据连接可使用的端口范围的最小端口，0：任意端口
listen=YES                      #服务是否以standalone模式运行。建议采用这种方式，此时listen须设为YES
listen_ipv6=NO     
max_clients=0                   #允许的最大连接数，默认为：0，即不受限制。仅standalone模式有效
max_per_ip=0                    #每个IP允许与FTP同时建立连接的数目。默认：0，即不受限制。仅standalone模式有效
#listen_address=IP地址          #设置FTP在指定的地址侦听用户请求。若不设置则对所有IP地址侦听。仅standalone模式有效
setproctitle_enable=YES         #每个与连接是否以不同进程展现。设为NO时使用："ps -ef|grep ftp"仅1个vsftpd进程                 
ascii_upload_enable=NO          
ascii_download_enable=NO

#匿名用户
anonymous_enable=NO             #是否启用匿名。登陆名：ftp或anonymous
no_anon_password=NO             #启用则匿名登录时不询问密码
ftp_username=ftp                #匿名登入时的身份。默认：ftp
anon_root=/var/ftp              #匿名登入时的目录。默认：/var/ftp（注意其不能是777的权限）
anon_upload_enable=NO           #是否允许匿名上传文件（非目录），仅write_enable=YES时有效（匿名须有对上层的w权。默认NO）
anon_world_readable_only= NO    #是否允许匿名下载r权限文档。默认：YES
anon_mkdir_write_enable=NO      #是否允许匿名有新增目录权限，仅write_enable=YES时有效（匿名须有对上层的w权。默认NO）
anon_other_write_enable=NO      #是否允许匿名更多于上传或建立目录之外的权限，如删除或重命名
chown_uploads= NO               #是否改变匿名上传文件（非目录）的属主。默认：NO。
chown_username=root             #匿名上传文件（非目录）的属主名。建议不要设为root！
anon_umask=077                  #匿名新增或上传档案时的umask。默认：077

#本地用户
local_enable=YES                #是否允许本地用户登陆
local_root=${chroot_dir:=/tmp}  #本地用户登入时被chroot的目录。默认为自身的家目录
write_enable=YES                #是否允许登陆用户有写权限。属于全局设置，默认：YES
local_umask=022                 #本地用户新增档案时的umask值。默认：077
file_open_mode=0755             #本地用户上传文件后的权限，与chmod所使用的数值相同。默认：0666。
        
#欢迎信息   
dirmessage_enable=NO            #若启用则用户第1次进入1个目录时将检查该目录是否有.message，若有则打印其内容
message_file=.message           #设置目录消息文件名，可将要显示的信息写入
#ftpd_banner=Welcome to  FTP    #用来定义欢迎语的字串，banner_file是档案的形式，而ftpd_banner则是字串形式
#banner_file=/etc/vsftpd/banner #用户登入时将显示此文件内容，通常为欢迎语或说明。默认为无
chroot_list_enable=NO                           #是否启用chroot_list_file配置项指定的用户列表文件。默认：NO
chroot_list_file=/etc/vsftpd.chroot_list        #指定用户列表文件，用于控制哪些用户可切换到家目录上级路径
chroot_local_user=NO                            #用于指定用户列表文件中的用户是否允许切换到上级目录。默认：NO

#访问控制
tcp_wrappers=NO                         #是否与tcp wrapper结合进行ACL。默认：YES。启用则检查：/etc/hosts.allow与/etc/hosts.deny
userlist_enable=NO                      #是否启用vsftpd.user_list文件
userlist_file=/etc/vsftpd.user_list     #控制用户访问FTP的文件，里面写着用户名称。一个用户名称一行
userlist_deny=NO                        #决定vsftpd.user_list中的用户是否能访问FTP。若YES则其中的用户不可访问FTP
download_enable=YES                     #如果设置为NO，所有的文件都不能下载到本地，文件夹不受影响。默认值为YES。
allow_writeable_chroot=YES              #开启...
pam_service_name=vsftpd                 #PAM认证相关

#速率设置
anon_max_rate=0                         #匿名的最大传输速度，单位：B/s，不限速：0。默认：0
local_max_rate=0                        #本地用户的最大传输速度，单位：B/s，不限速：0。预设：0
        
#超时设置   
accept_timeout=45                       #建立21端口连接的超时时间，单位s。默认：60
connect_timeout=45                      #PORT模式下建立数据连接的超时时间，单位s。默认：60
data_connection_timeout=60              #设置建立FTP数据连接的超时时间，单位s。默认：120
idle_session_timeout=120                #多长时间不对FTP服务器进行操作则断开连接，单位s。默认：300

#日志设置
xferlog_enable=YES                      #是否启用上传/下载日志。若启用则相应信息将被纪录在xferlog_file定义的文件内。默认：YES
xferlog_file=/var/log/vsftpd.log        #日志文件，默认：/var/log/vsftpd.log
xferlog_std_format=NO                   #若启用则日志将写成xferlog标准格式。默认关闭
log_ftp_protocol=NO                     #所有FTP请求和响应是否被记录到日志，若启用额xferlog_std_format不能被激活。默认：NO

#用户配置文件
#user_config_dir=/etc/vsftpd/userconf  
#用户配置文件所在目录。当设置该项后用户登陆时系统会到指定目录下读取与当前用户名相同的文件，并据文件中的配置命令对当前用户进行更进一步的配置
#用户配置文件可实现对不同用户进行访问速度的控制，在各用户配置文件中定义local_max_rate=XX即可
eof

echo -e "\033[32mConfig：${config_file}\033[0m"

#执行
[ -e /usr/bin/systemctl ] && {
  systemctl restart vsftpd
  systemctl enable vsftpd
  echo "Vsftp start ..."
}

[ -e /usr/bin/systemctl ] || {
  chkconfig vsftpd --level 235 on
  service vsftpd start
  echo "Vsftp start ..."
}


# 注：
# 在文件/etc/vsftpd.ftpusers中的本地用户禁止登陆
# 当chroot_list_enable=YES，chroot_local_user=YES，在/etc/vsftpd.chroot_list文件中列出的用户，可以切换到其他目录；未在文件中列出的用户，不能切换到其他目录。
# 当chroot_list_enable=YES，chroot_local_user=NO，在/etc/vsftpd.chroot_list文件中列出的用户，不能切换到其他目录；未在文件中列出的用户，可以切换到其他目录。
# 当chroot_list_enable=NO，chroot_local_user=YES，所有的用户均不能切换到其他目录。
# 当chroot_list_enable=NO，chroot_local_user=NO，所有的用户均可以切换到其他目录。

# PORT模式：
# FTP客户端连接到FTP服务器的21端口，发送用户名和密码
# 登录成功后要list或读取数据时客户端随机开放一个端口（N>1024），发送 PORT命令到FTP服务器，告诉服务器客户端采用主动模式并开放端口
# 服务器收到PORT主动模式命令和端口号后，通过自身20端口和客户端开放的端口连接

# PASV模式：
# 中文成为被动模式，工作原理：FTP客户端连接到FTP服务器的21端口，发送用户名和密码
# 登录成功后要list或者读取数据时发送PASV命令到服务器， 服务器在本地随机开放一个端口（N>1024），然后把开放的端口告诉客户端
# 客户端再连接到服务器开放的端口进行传输

