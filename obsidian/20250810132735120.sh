echo "proxy.sh start work"

CHARLES_PROXY_PORT=8888
PROXY_PORT_PROXYMAN=9090

##############################################
#################### proxy ###################
##############################################
# 参数1：adb shell后面的命令，如ls
# 参数2：设备的正则表达式，用于匹配设备
function adb:shell:proxy() {
    COMMAND=$1
    # 获取设备数量
    device_count=$(adb devices | grep -v 'List of devices' | grep 'device$' | wc -l)
    # 判断设备数量
    if [ "$device_count" -eq 0 ]; then
        echo "没有检测到已连接的设备。"
    elif [ "$device_count" -eq 1 ]; then
        echo "检测到一台设备。进入shell模式，execute: $COMMAND"
        adb shell "$COMMAND"
    else
        adb devices
        DEVICE_REGEX=$2
        # 如果未提供 DEVICE_REGEX，使用空字符串
        devices_regex=${DEVICE_REGEX:-""}
        echo "devices_regex=$devices_regex"
        # 首先获取设备列表
        device_list=$(adb devices | grep 'device$')

        # 如果 DEVICE_REGEX 为空，则获取第一个设备
        if [ -z "$devices_regex" ]; then
            echo "未设置 devices_regex，默认选择第一个设备。"
            matching_device=$(echo "$device_list" | head -n 1 | awk '{print $1}')
        else
            # 否则，按照 devices_regex 来匹配设备
            matching_devices=$(echo "$device_list" | grep "$devices_regex" | awk '{print $1}')
            matching_device=$(echo "$matching_devices" | head -n 1)
        fi

        # 连接到匹配的设备
        if [ -n "$matching_device" ]; then
            echo "连接到设备：$matching_device，execute: $COMMAND"
            adb -s "$matching_device" shell "$COMMAND"
        else
            echo "没有找到匹配的设备。"
        fi
    fi
}
# 多个ip手动输入
function proxyhelper_multi_devices() {
    local operator=$1 #=号两边不能有空格
    if [[ -z "${operator}" ]]; then
        echo -e "\033[31mFATAL: 请输入合法的proxyhelper命令： \033[0m"
        echo "设置代理：本机IP:8888       proxyhelper set"
        echo "设置代理：本机IP:port       proxyhelper set port"
        echo "设置代理： ip:port         proxyhelper set ip port"
        echo "获取当前代理：              proxyhelper get"
        echo "删除代理：                 proxyhelper clear"
        return 0
    fi
    if [[ "$operator" == "set" ]]; then
        if [ $# -eq 3 ]; then # set后2个参数的是ip:port
            IP=$2
            PROT=$3
            echo "设置自定义代理 $IP:$PROT"
            adb shell settings put global http_proxy $IP:$PROT
        elif [ $# -eq 2 ]; then # set后1个参数的是port
            PROT=$2
            # 获取 IP
            ip=$(/sbin/ifconfig | /usr/bin/sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
            echo "可用IP地址："
            echo "$ip"
            count=$(echo $ip | /usr/bin/tr ' ' '\n' | /usr/bin/wc -l)
            if [ $count -gt 1 ]; then
                echo "请输入要使用的IP地址："
                read selected_ip
                default_proxy=${selected_ip}":$PROT"
            else
                default_proxy=${ip}":$PROT"
            fi
            echo "设置代理为 $default_proxy"
            adb:shell:proxy "settings put global http_proxy $default_proxy"
        else # 0个参数的是默认端口：8888
            # 获取 IP
            ip=$(/sbin/ifconfig | /usr/bin/sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
            count=$(echo $ip | /usr/bin/tr ' ' '\n' | /usr/bin/wc -l)
            if [ $count -gt 1 ]; then
                echo "可用IP地址："
                echo "$ip"
                echo "请输入要使用的IP地址："
                read selected_ip
                default_proxy=${selected_ip}":$CHARLES_PROXY_PORT"
            else
                default_proxy=${ip}":$CHARLES_PROXY_PORT"
            fi
            adb:shell:proxy "settings put global http_proxy $default_proxy"
            echo "设置代理为 $default_proxy"
        fi
    elif [[ $operator == "get" ]]; then
        echo "当前代理："
        adb:shell:proxy 'settings get global http_proxy'
    elif [[ $operator == "clear" ]]; then
        echo "清除代理成功！"
        adb:shell:proxy 'settings put global http_proxy :0'
        # 下面的方式需要重启手机
        # adb shell settings delete global http_proxy
        # adb shell settings delete global global_http_proxy_host
        # adb shell settings delete global global_http_proxy_port
    else
        echo -e "\033[31mFATAL: 请输入合法的proxyhelper命令： \033[0m"
        echo "设置代理：本机IP:8888       proxyhelper set"
        echo "设置代理：本机IP:port       proxyhelper set port"
        echo "设置代理： ip:port         proxyhelper set ip port"
        echo "获取当前代理：              proxyhelper get"
        echo "删除代理：                 proxyhelper clear"
    fi
}
# 多个ip就exit了，一些代理软件开启VPN后会有多个ip，如：Hiddify
function proxyhelper() {
    local operator=$1 #=号两边不能有空格
    if [[ -z "${operator}" ]]; then
        echo -e "\033[31mFATAL: 请输入合法的proxyhelper命令： \033[0m"
        echo "设置代理：本机IP:8888       proxyhelper set"
        echo "设置代理：本机IP:port       proxyhelper set port"
        echo "设置代理： ip:port         proxyhelper set ip port"
        echo "获取当前代理：              proxyhelper get"
        echo "删除代理：                 proxyhelper clear"
        return 0
    fi
    if [[ "$operator" == "set" ]]; then
        if [ $# -eq 3 ]; then # set后2个参数的是ip:port
            IP=$2
            PROT=$3
            echo "设置自定义代理 $IP:$PROT"
            adb shell settings put global http_proxy $IP:$PROT
        elif [ $# -eq 2 ]; then # set后1个参数的是port
            PROT=$2
            # 获取 IP
            ip=$(/sbin/ifconfig | /usr/bin/sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
            echo $ip
            count=$(echo $ip | /usr/bin/tr ' ' '\n' | /usr/bin/wc -l)
            if [ $count -gt 1 ]; then
                echo "多个ip, 请手动选择一个"
                # exit
            fi
            default_proxy=${ip}":$PROT"
            echo "设置代理为本机IP: $default_proxy"
            adb shell settings put global http_proxy $default_proxy
        else # 0个参数的是默认端口：8888
            # 获取 IP
            ip=$(/sbin/ifconfig | /usr/bin/sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
            # echo $ip
            count=$(echo $ip | /usr/bin/tr ' ' '\n' | /usr/bin/wc -l)
            if [ $count -gt 1 ]; then
                echo "多个ip, 请手动选择一个"
                # exit
            fi
            default_proxy=${ip}":$CHARLES_PROXY_PORT"
            echo "设置代理为本机IP(默认port:8888): $default_proxy"
            adb shell settings put global http_proxy $default_proxy
        fi
    elif [[ $operator == "get" ]]; then
        echo "当前代理："
        adb shell settings get global http_proxy
    elif [[ $operator == "clear" ]]; then
        echo "清除代理成功！"
        adb shell settings put global http_proxy :0
        # 下面的方式需要重启手机
        # adb shell settings delete global http_proxy
        # adb shell settings delete global global_http_proxy_host
        # adb shell settings delete global global_http_proxy_port
    else
        echo -e "\033[31mFATAL: 请输入合法的proxyhelper命令： \033[0m"
        echo "设置代理：本机IP:8888       proxyhelper set"
        echo "设置代理：本机IP:port       proxyhelper set port"
        echo "设置代理： ip:port         proxyhelper set ip port"
        echo "获取当前代理：              proxyhelper get"
        echo "删除代理：                 proxyhelper clear"
    fi
}


## charles proxy抓包
function proxy:on() { # 设置charles全局代理
    proxyhelper set $CHARLES_PROXY_PORT
}
function proxyman:on() { # 设置proxyman全局代理
    proxyhelper set $PROXY_PORT_PROXYMAN
}
function proxyman:off() { # 设置proxyman全局代理
    proxyhelper clear $PROXY_PORT_PROXYMAN
}
function proxy:get() { # 获取当前代理
    proxyhelper get
}
function proxy:off() { # 清除charles全局代理
    proxyhelper clear
}
