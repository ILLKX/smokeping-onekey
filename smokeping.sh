#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#定义终端输出颜色
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

#定义文件路径
smokeping_ver="/opt/smokeping/onekeymanage/ver"
smokeping_key="/opt/smokeping/onekeymanage/key"
smokeping_name="/opt/smokeping/onekeymanage/name"
smokeping_host="/opt/smokeping/onekeymanage/host"
tcpping="/usr/bin/tcpping"

#Check Root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

#获取进程PID
Get_PID(){
	PID=(`ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|awk '{print $2}'|xargs`)
}

#更换安装包源
Change_Source(){
	yum clean all
	wget -O /etc/yum.repos.d/CentOS-Base.repo https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/CentOS-Base.repo
	wget -O /etc/yum.repos.d/epel.repo https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/epel-7.repo
}

#安装elep
Install_Epel(){
	yum install epel-release -y
}

#安装依赖
Install_Dependency(){
	yum install rrdtool perl-rrdtool perl-core openssl-devel fping curl gcc-c++ make wqy-zenhei-fonts.noarch supervisor -y
}

#下载smokeping
Download_Source(){
	cd
	wget https://github.com/ILLKX/smokeping-onekey/raw/master/smokeping-2.6.11.tar.gz
	tar -xzvf smokeping-2.6.11.tar.gz
	cd smokeping-2.6.11
}

#安装smokeping
Install_SomkePing(){
	./setup/build-perl-modules.sh /opt/smokeping/thirdparty
	./configure --prefix=/opt/smokeping
	make install
}

#清除文件
Delete_Files(){
	rm -rf /root/smokeping-2.6.*
}

#配置smokeping
Configure_SomkePing(){
	cd /opt/smokeping/htdocs
	mkdir var cache data
	mv smokeping.fcgi.dist smokeping.fcgi
	cd /opt/smokeping/etc
	rm -rf config*
	wget -O config https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/config
	wget -O /opt/smokeping/lib/Smokeping/Graphs.pm https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/Graphs.pm
	chmod 600 /opt/smokeping/etc/smokeping_secrets.dist
}

#配置config Master
Master_Configure_SomkePing(){
	cd /opt/smokeping/etc
	sed -i "s/some.url/$server_name/g" config
}

#安装Nginx及其他软件
Install_Nginx(){
	yum install nginx spawn-fcgi -y
}

#修改Nginx配置文件
Configure_Nginx(){
	wget -O /etc/nginx/conf.d/smokeping.conf https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/smokeping.conf
	rm -rf /etc/nginx/nginx.conf
	wget -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/nginx.conf
}

#修改Nginx配置文件 Master
Master_Configure_Nginx(){
	wget -O /etc/nginx/conf.d/smokeping.conf https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/smokeping-master.conf
	sed -i "s/local/$server_name/g" /etc/nginx/conf.d/smokeping.conf
	rm -rf /etc/nginx/nginx.conf
	wget -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/nginx.conf
}

#启动Nginx并禁用防火墙
Start_Nginx_Disable_Firewall(){
	systemctl start nginx
	systemctl stop firewalld
	systemctl disable firewalld
}

#禁用SELinux
Disable_SELinux(){
	setenforce 0
	sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
	sed -i "s/SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config
}

#修改smokeping权限
Change_Access(){
	chown -R nginx:nginx /opt/smokeping/htdocs
	chown -R nginx:nginx /opt/smokeping/etc/smokeping_secrets.dist
}

#设置Slaves密钥
Slaves_Set_Secret(){
	rm -rf /opt/smokeping/etc/smokeping_secrets.dist
	echo -e "${slaves_secret}" > /opt/smokeping/etc/smokeping_secrets.dist
}

#配置supervisor
Configure_Supervisor(){
	wget -O /etc/supervisord.d/spawnfcgi.ini https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/spawnfcgi.ini
	supervisord -c /etc/supervisord.conf
	systemctl enable supervisord.service
	systemctl start supervisord.service
	systemctl reload supervisord.service
}

#启动Single服务
Single_Run_SmokePing(){
	cd /opt/smokeping/bin
	./smokeping --config=/opt/smokeping/etc/config --logfile=smoke.log
	supervisorctl start spawnfcgi
	Change_Access
}

#启动Master服务
Master_Run_SmokePing(){
	cd /opt/smokeping/bin
	./smokeping --config=/opt/smokeping/etc/config --logfile=smoke.log
	supervisorctl start spawnfcgi
	Change_Access
}

#启动Slaves服务
Slaves_Run_SmokePing(){
	cd /opt/smokeping/bin
	./smokeping --master-url=http://$server_name/smokeping.fcgi --cache-dir=/opt/smokeping/htdocs/cache --shared-secret=/opt/smokeping/etc/smokeping_secrets.dist --slave-name=$slaves_name --logfile=/opt/smokeping/slave.log
}

Single_Install(){
	echo
	kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
	rm -rf /opt/smokeping
	Ask_Change_Source
	Install_Dependency
	Download_Source
	Install_SomkePing
	Configure_SomkePing
	Install_Nginx
	Configure_Nginx
	Start_Nginx_Disable_Firewall
	Change_Access
	Disable_SELinux
	Configure_Supervisor
	Delete_Files
	mkdir /opt/smokeping/onekeymanage
	echo "Single" > ${smokeping_ver}
	echo -e "${Info} 安装 SmokePing 单机版完成"
}

Slaves_Install(){
	echo
	read -p "请输入Master地址 : " server_name
	read -p "请输入Slaves名称 : " slaves_name
	read -p "请输入Slaves密钥 : " slaves_secret
	kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
	rm -rf /opt/smokeping
	Ask_Change_Source
	Install_Dependency
	Download_Source
	Install_SomkePing
	Slaves_Set_Secret
	Configure_SomkePing
	Disable_SELinux
	Delete_Files
	mkdir /opt/smokeping/onekeymanage
	echo "Slaves" > ${smokeping_ver}
	echo -e "${slaves_secret}" > ${smokeping_key}
	echo -e "${slaves_name}" > ${smokeping_name}
	echo -e "${server_name}" > ${smokeping_host}
	echo -e "${Info} 安装 SmokePing Slaves端完成"
}

Master_Install(){
	echo
	read -p "请输入Master地址 : " server_name
	kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
	rm -rf /opt/smokeping
	Ask_Change_Source
	Install_Dependency
	Download_Source
	Install_SomkePing
	Configure_SomkePing
	Master_Configure_SomkePing
	Install_Nginx
	Master_Configure_Nginx
	Start_Nginx_Disable_Firewall
	Change_Access
	Disable_SELinux
	Configure_Supervisor
	Delete_Files
	mkdir /opt/smokeping/onekeymanage
	echo "Master" > ${smokeping_ver}
	echo -e "${Info} 安装 SmokePing Master端完成"
}

#询问是否换源
Ask_Change_Source(){
	while :; do echo
		echo -e "${Tip} 是否将系统源更换成阿里云源 (国内外均可用) [y/n]： "
		read ifchangesource
		if [[ ! $ifchangesource =~ ^[y,n]$ ]]; then
			echo "输入错误! 请输入y或者n!"
		else
			break
		fi
	done
	if [[ $ifchangesource == y ]]; then
		Change_Source
	else
		Install_Epel
	fi
	yum install wget -y
}

Install_Tcpping(){
	cd
	yum install tcptraceroute -y
	rm -rf /usr/bin/tcpping
	wget https://raw.githubusercontent.com/ILLKX/smokeping-onekey/master/tcpping
	chmod 777 tcpping
	mv tcpping /usr/bin/
	echo -e "${Info} 安装 tcpping 完成"
}

#卸载SmokePing
Uninstall(){
	while :; do echo		
		echo -e "${Tip} 已经安装${Green_font_prefix} $mode2 ${Font_color_suffix}，是否卸载 [y/n]: "
		read um
		if [[ ! $um =~ ^[y,n]$ ]]; then
			echo "输入错误! 请输入y或者n!"
		else
			break
		fi
	done
	if [[ $um == "y" ]]; then
		kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
		rm -rf /opt/smokeping
		rm -rf /usr/bin/tcpping
		echo
		echo -e "${Info} SmokePing 卸载完成!"
		echo
	else
		echo
		echo -e "${Info} 卸载已取消!"
		echo
		exit
	fi
}

clear

echo && echo -e "  SmokePing 一键管理脚本 
  
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 SmokePing Master端
 ${Green_font_prefix} 2.${Font_color_suffix} 安装 SmokePing Slaves端
 ${Green_font_prefix} 3.${Font_color_suffix} 安装 SmokePing 单机版
 ${Green_font_prefix} 4.${Font_color_suffix} 卸载 SmokePing
  ————————————
 ${Green_font_prefix} 5.${Font_color_suffix} 启动 SmokePing
 ${Green_font_prefix} 6.${Font_color_suffix} 停止 SmokePing
 ${Green_font_prefix} 7.${Font_color_suffix} 重启 SmokePing
  ————————————
 ${Green_font_prefix} 8.${Font_color_suffix} 安装 Tcpping
  ————————————
 ${Green_font_prefix} 9.${Font_color_suffix} 退出
  ————————————" && echo
if [[ -e ${smokeping_ver} ]]; then
	Get_PID
	if [[ `grep "Slaves" ${smokeping_ver}` ]]; then
		mode="Slaves"
		mode2="Slaves端"
		slaves_secret=(`cat ${smokeping_key}`)
		slaves_name=(`cat ${smokeping_name}`)
		server_name=(`cat ${smokeping_host}`)
	fi
	if [[ `grep "Master" ${smokeping_ver}` ]]; then
		mode="Master"
		mode2="Master端"
	fi
	if [[ `grep "Single" ${smokeping_ver}` ]]; then
		mode="Single"
		mode2="单机版"
	fi
	if [[ ! -z "${PID}" ]]; then
		echo -e "当前状态: ${Green_font_prefix}已安装 $mode2 ${Font_color_suffix}并 ${Green_font_prefix}已启动${Font_color_suffix}"
	else
		echo -e "当前状态: ${Green_font_prefix}已安装 $mode2 ${Font_color_suffix}但 ${Red_font_prefix}未启动${Font_color_suffix}"
	fi
else
	echo -e "当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
fi
echo
if [[ ! -e ${tcpping} ]]; then
	echo -e "Tcpping状态: ${Red_font_prefix}未安装${Font_color_suffix}"
else
	echo -e "Tcpping状态: ${Green_font_prefix}已安装${Font_color_suffix}"
fi
echo
read -p "请输入数字 [1-9]:" num

case "$num" in
	
1)
	if [[ -e ${smokeping_ver} ]]; then
		while :; do echo
			echo -e "${Tip} 已经安装${Green_font_prefix} $mode2 ${Font_color_suffix}，是否重新安装 [y/n]: "
			read um
			if [[ ! $um =~ ^[y,n]$ ]]; then
				echo "输入错误! 请输入y或者n!"
			else
				break
			fi
		done
		if [[ $um == "y" ]]; then
			kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
			rm -rf /opt/smokeping
			rm -rf /usr/bin/tcpping
			supervisorctl stop spawnfcgi
			echo
			echo -e "${Info} Smokeping ${mode2} 卸载完成! 开始安装 Master端!"
			echo
			sleep 5
			Master_Install
			exit
		else
			exit
		fi
	fi
	Master_Install
;;
2)
	if [[ -e ${smokeping_ver} ]]; then
		while :; do echo
			echo -e "${Tip} 已经安装${Green_font_prefix} $mode2 ${Font_color_suffix}，是否重新安装 [y/n]: "
			read um
			if [[ ! $um =~ ^[y,n]$ ]]; then
				echo "输入错误! 请输入y或者n!"
			else
				break
			fi
		done
		if [[ $um == "y" ]]; then
			kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
			rm -rf /opt/smokeping
			rm -rf /usr/bin/tcpping
			supervisorctl stop spawnfcgi
			echo
			echo -e "${Info} Smokeping ${mode2} 卸载完成! 开始安装 Slaves端!"
			echo
			sleep 5
			Slaves_Install
			exit
		else
			exit
		fi
	fi
	Slaves_Install
;;
3)
	if [[ -e ${smokeping_ver} ]]; then
		while :; do echo
			echo -e "${Tip} 已经安装${Green_font_prefix} $mode2 ${Font_color_suffix}，是否重新安装 [y/n]: "
			read um
			if [[ ! $um =~ ^[y,n]$ ]]; then
				echo "输入错误! 请输入y或者n!"
			else
				break
			fi
		done
		if [[ $um == "y" ]]; then
			kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
			rm -rf /opt/smokeping
			rm -rf /usr/bin/tcpping
			supervisorctl stop spawnfcgi
			echo
			echo -e "${Info} Smokeping ${mode2} 卸载完成! 开始安装 单机版!"
			echo
			sleep 5
			Single_Install
			exit
		else
			exit
		fi
	fi
	Single_Install
;;

4)
	[[ ! -e ${smokeping_ver} ]] && echo -e "${Error} Smokeping 没有安装，请检查!" && exit 1
	Uninstall
;;

5)
	[[ ! -e ${smokeping_ver} ]] && echo -e "${Error} Smokeping 没有安装，请检查!" && exit 1
	${mode}_Run_SmokePing
;;

6)
	[[ ! -e ${smokeping_ver} ]] && echo -e "${Error} Smokeping 没有安装，请检查!" && exit 1
	kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
	supervisorctl stop spawnfcgi
;;

7)
	[[ ! -e ${smokeping_ver} ]] && echo -e "${Error} Smokeping 没有安装，请检查!" && exit 1
	kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|grep -v "perl"|awk '{print $2}'|xargs` 2>/dev/null
	${mode}_Run_SmokePing
;;

8)
	if [[ -e ${tcpping} ]]; then
		while :; do echo
			echo -e "${Tip} 已经安装${Green_font_prefix} tcpping ${Font_color_suffix}，是否重新安装 [y/n]: "
			read um
			if [[ ! $um =~ ^[y,n]$ ]]; then
				echo "输入错误! 请输入y或者n!"
			else
				break
			fi
		done
		if [[ $um == "y" ]]; then
			rm -rf /usr/bin/tcpping
			echo
			echo -e "${Info} tcpping 卸载完成! 开始安装 Tcpping!"
			echo
			sleep 5
			Install_Tcpping
			exit
		else
			exit
		fi
	fi
	Install_Tcpping
;;

9)
	exit
;;

*)
	echo "输入错误! 请输入正确的数字! [1-9]"
;;

esac
