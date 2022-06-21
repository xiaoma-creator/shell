#!/bin/ash
# shellcheck shell=bash

#存储文件路径
g_save_file="/tmp/ip_find_recorde.txt"                   

#将IP转为16进制形式
ip_2_hex(){
    local ip=$1
    local IPType_1=""
    local IPType_2=""
    local IPType_3=""
    local IPType_4=""

    IPType_1=$(echo "$ip" | cut -d. -f1)
    IPType_2=$(echo "$ip" | cut -d. -f2)
    IPType_3=$(echo "$ip" | cut -d. -f3)
    IPType_4=$(echo "$ip" | cut -d. -f4)   

    #IP地址16进制形式
    local IPHex_1=$((IPType_1<<24))
    local IPHex_2=$((IPType_2<<16))
    local IPHex_3=$((IPType_3<<8))
    local IPHex_4=$((IPType_4))
    local IPHex=$((IPHex_1+IPHex_2+IPHex_3+IPHex_4))
    
    echo "${IPHex}"
}

#将16进制IP地址转为点分式
hex_2_ip(){
    local IPHex=$1

    #转化为点分式
    local IPHex_1=$((IPHex>>24 & 0x000000ff))
    local IPHex_2=$((IPHex>>16 & 0x000000ff))
    local IPHex_3=$((IPHex>>8 & 0x000000ff))
    local IPHex_4=$((IPHex & 0x000000ff))

    echo "${IPHex_1}.${IPHex_2}.${IPHex_3}.${IPHex_4}"
}

#ping 单个ip, ping通后将IP写入g_save_file
#ping_one_ip <$1> [$2]
#<$1>：目的IP
#[$2]: 可指定源IP
ping_one_ip(){
    local desIp=$1
    local srcIp=$2
    local result=""
    
    if [ -n "${srcIp}" ]; then
        ping -I "${srcIp}" "${desIp}" -w 1 > /dev/null
    else
    	ping  "${desIp}" -w 1 > /dev/null
    fi
    
    if [ $? = 0 ]; then
        #互斥锁
        #exec 4<>$g_save_file
        #flock -n 4 || flock 4
        echo "ping ${desIp} success, write to ${g_save_file}!"
        echo "${desIp}" >> "${g_save_file}"
    # else
    #     echo "ping ${desIp} failed"
    fi
}

#ping网段IP
ping_part_ip(){
    local ipAndNetwork=$1
    local ip=""
    local network=""
    local broadcast=""
    local ipHex=0
    local networkHex=0
    local broadcastHex=0
    local i=0

    #多进程初始化
    #start=$(date +%s)
    [ -f "${g_fifo_path}" ] && rm "${g_fifo_path}"
    mkfifo "${g_fifo_path}"
    exec 3<>"${g_fifo_path}"
    rm "${g_fifo_path}"
    i=0
    while [ $i -lt "${g_process_max}" ]
    do
        echo >&3
        i=$((i + 1))
    done

    #网络号、广播地址
    network=$(ipcalc.sh "${ipAndNetwork}" | grep NETWORK | cut -d = -f 2)
    networkHex=$(ip_2_hex "${network}")
    broadcast=$(ipcalc.sh "${ipAndNetwork}" | grep BROADCAST | cut -d = -f 2)
    broadcastHex=$(ip_2_hex "${broadcast}")

    #lan口ip
    br_lan_ip=$(ifconfig br-lan | grep -w inet | awk '{print $2}' | cut -d :  -f 2)
    br_lan0_ip=$(ifconfig br-lan:0 | grep -w inet | awk '{print $2}' | cut -d :  -f 2)

    ipHex=${networkHex}
    while [ "${ipHex}" -lt "${broadcastHex}" ]
    do
        read -ru3
        ipHex=$((ipHex + 1))
    {
        ip=$(hex_2_ip "${ipHex}")
        #过滤LAN口IP、广播地址
        [ "${ip}" != "${br_lan_ip}" ] && [ "${ip}" != "${br_lan0_ip}" ] && [ "${ip}" != "${broadcast}" ] && ping_one_ip "${ip}"
        echo >&3
    }&
    done
    wait
    #回收描述符
    exec 3<&-
    exec 3>&-
    
    #end=$(date +%s)
    #echo "use time : $((end - start))"
}

ping_all_ip(){
    local i=0
    local j=0
    local k=1
    local ip=""
    local result=""
    local lanIp=""
    local lanIpTmp=""

    #10.0.0.0~10.255.255.255
    if result=$(is_same_network "10.0.0.0"); then
       lanIp=$(ifconfig "${result}" | grep -w inet | awk '{print $2}' | cut -d :  -f 2)
       lanIpTmp=$(ip_add_1 "${lanIp}")
       ifconfig -a "${result}" "${lanIpTmp}"
       ping_one_ip "${lanIp}"
       ifconfig -a "${result}" "${lanIp}"

       while [ ${i} -lt 255 ]
       do
           while [ ${j} -lt 255 ]
           do
               while [ ${k} -lt 255 ]
               do
                   ip="10.${i}.${j}.${k}"
                   
                   k=$((k + 1))
                   [ "${ip}" = "${lanIp}" ] && continue
                   #echo ${ip}
                   ping_one_ip ${ip} 
               done
               k=1
               j=$((j + 1))
           done
           j=0
           i=$((i + 1))
       done
       i=0       
    else
       set_br_lan0_ip "10.0.0.1"
       while [ ${i} -lt 255 ]
       do
           while [ ${j} -lt 255 ]
           do
               while [ ${k} -lt 255 ]
               do
                   ip="10.${i}.${j}.${k}" 
                   k=$((k + 1))
                   [ ${ip} = "10.0.0.1" ] && continue
                   #echo ${ip}
                   ping_one_ip ${ip}
               done
               k=1
               j=$((j + 1))
           done
           j=0
           i=$((i + 1))
       done
       i=0

       set_br_lan0_ip "10.0.0.2"
       ping_one_ip "10.0.0.1"
       set_br_lan0_ip "${g_brlan0_ip_buff}"           
    fi

    #172.16.0.0~172.31.255.255
    i=16
    j=0
    k=1
    while [ ${i} -lt 31 ]
    do
       if result=$(is_same_network "172.${i}.0.0");then
           echo "same"
           lanIp=$(ifconfig "${result}" | grep -w inet | awk '{print $2}' | cut -d :  -f 2)
           lanIpTmp=$(ip_add_1 "${lanIp}")
           ifconfig -a "${result}" "${lanIpTmp}"
           ping_one_ip "${lanIp}"
           ifconfig -a "${result}" "${lanIp}"

           while [ $j -lt 255 ]
           do
               while [ $k -lt 255 ]
               do
                   ip="172.${i}.${j}.${k}"
                   k=$((k + 1))
                   [ "${ip}" = "${lanIp}" ] && continue
                   #echo ${ip}
                   ping_one_ip ${ip}
               done
               k=1
               j=$((j + 1))
           done 
           j=0
       else
           echo "not same"

           set_br_lan0_ip "172.${i}.0.1"
           while [ $j -lt 255 ]
           do
               while [ $k -lt 255 ]
               do
                   ip="172.${i}.${j}.${k}"
                   k=$((k + 1))
                   [ "${ip}" = "172.${i}.0.1" ] && continue
                   #echo ${ip}
                   ping_one_ip ${ip}
               done
               k=1
               j=$((j + 1))
           done 
           j=0
       fi
       i=$((i + 1))
    done
    i=0

    set_br_lan0_ip "${g_brlan0_ip_buff}"

    #192.168.0.0~192.168.255.255
    i=0
    j=1
    while [ $i -lt 255 ]
    do
        if result=$(is_same_network "192.168.${i}.0");then
            echo "same"

            lanIp=$(ifconfig "${result}" | grep -w inet | awk '{print $2}' | cut -d :  -f 2)
            lanIpTmp=$(ip_add_1 "${lanIp}")
            ifconfig -a "${result}" "${lanIpTmp}"
            ping_one_ip "${lanIp}"
            ifconfig -a "${result}" "${lanIp}"

            while [ $j -lt 255 ]
            do
                ip="192.168.${i}.${j}"
                j=$((j + 1))
                [ ${ip} = "${lanIp}" ] && continue
                #echo "${ip}"
                ping_one_ip "${ip}"
            done
        else
            echo "not same"

            set_br_lan0_ip "192.168.${i}.1"
            while [ $j -lt 255 ]
            do
                ip="192.168.${i}.${j}"
                j=$((j + 1))
                [ ${ip} = "${lanIp}" ] && continue
                #echo "${ip}"
                ping_one_ip "${ip}"
            done

            set_br_lan0_ip "192.168.${i}.2"
            ping_one_ip "192.168.${i}.1"
            set_br_lan0_ip "192.168.${i}.1"

        fi
        j=1
        i=$((i + 1))
    done

    set_br_lan0_ip "${g_brlan0_ip_buff}"
}

#ping单个IP还是ping网段内IP
ping_select_one_or_part(){
    local ipAndMask=$1

    if is_ip_and_mask "${ipAndMask}"; then
        local ip=${ipAndMask%/*}
        #判断是否为IP地址而不是网段
        tmp=$(echo "${ip}" | cut -d . -f 4)
        if [ 0 -eq "${tmp}" ];then
            #网段
            ping_part_ip "${ipAndMask}"
        else
            #单个IP
            ping_one_ip "${ip}"
        fi
    fi
}

#判断是否为ip地址+子网前缀
is_ip_and_mask(){
    local ipAndNetwork=$1
    local ipRegular='^((2(5[0-5]|[0-4][0-9]))|[0-1]?[0-9]{1,2})(\.((2(5[0-5]|[0-4][0-9]))|[0-1]?[0-9]{1,2})){3}/(3[0-2]|[1-2][0-9]|[1-9])$'
    local result

    result=$(echo "${ipAndNetwork}" | grep -E "${ipRegular}")
    [ -n "${result}" ] || {
        echo "bad ip address ${ipAndNetwork}"
        echo "please input such as 192.168.10.1/32"
        return 1
    }

    return 0
}

usage(){
    echo
    echo "Usage:"
    echo "$0 [option]"
    echo "$0 -s <ip/mask> ..."
    echo
    echo "Parse command option"
    echo
    echo "Option:"
    echo "  -a        scan for all ip address"
    #echo "  -r        reset br-lan:0 ip (${g_brlan0_ip_buff})"
    echo "  -s        set up the network segment for scanning "
    echo "            such as:"
    echo "            $0 -s 192.168.10.0/24 192.168.20.0/24"
    echo "            $0 -s 192.168.58.8/32" 
    echo
    echo "  -h        display this help and exit"
    echo
    
}

set_br_lan0_ip(){
    local ip=$1

    ifconfig -a br-lan:0 "${ip}"
}

set_br_lan_ip(){
    local ip=$1

    ifconfig -a br-lan "${ip}"
}

#是否跟LAN口在同一网段
#输出相同的接口名
is_same_network(){
    local br_lan_ip=""
    local br_lan_mask=""
    local br_lan_network=""
    local br_lan0_ip=""
    local br_lan0_mask=""
    local br_lan0_network=""
    local network=$1

    #获取LAN口IP和掩码
    br_lan_ip=$(ifconfig br-lan | grep -w inet | awk '{print $2}' | cut -d :  -f 2)
    br_lan_mask=$(ifconfig br-lan | grep -w inet | awk '{print $4}' | cut -d :  -f 2)
    br_lan0_ip=$(ifconfig br-lan:0 | grep -w inet | awk '{print $2}' | cut -d :  -f 2)
    br_lan0_mask=$(ifconfig br-lan:0 | grep -w inet | awk '{print $4}' | cut -d :  -f 2)

    #计算网络号
    br_lan_network=$(ipcalc.sh "${br_lan_ip}" "${br_lan_mask}" | grep NETWORK | cut -d = -f 2)
    br_lan0_network=$(ipcalc.sh "${br_lan0_ip}" "${br_lan0_mask}"  | grep NETWORK | cut -d = -f 2)

    [ "${network}" = "${br_lan_network}" ] && { 
        echo "br-lan"
        return 0 
    }
    [ "${network}" = "${br_lan0_network}" ] && { 
        echo "br-lan:0"
        return 0 
    }
    
    return 1
}

ip_add_1(){
    local ip=$1
    local IPHex=0

    IPHex=$(ip_2_hex "${ip}") #转化为16进制
    IPHex=$((IPHex + 1))
    ip=$(hex_2_ip "${IPHex}")

    echo "${ip}"  
}

find_ip(){
    local ipAndNetwork=$1   #ip + 掩码长度
    local network=""
    local ip=""
    local tmp=""
    local br_lan0_ip=""
    local result=""

    #判断是否为ip地址+子网前缀
    if ! is_ip_and_mask "${ipAndNetwork}"; then
        return 1
    fi

    #网络号
    network=$(ipcalc.sh "${ipAndNetwork}" | grep NETWORK | cut -d = -f 2)

    #判断LAN口跟目的ip是否在同一个网段
    if result=$(is_same_network "${network}") ;then
        #echo "same ${result}"

        #判断是IP地址还是网段
        ip=${ipAndNetwork%/*}
        tmp=$(echo "${ip}" | cut -d . -f 4)
        if [ 0 -eq "${tmp}" ];then
            #网段
            ping_part_ip "${ipAndMask}"

            #将LAN口IP成 （lan_ip + 1）  ping  lan口IP
            if [ "${result}" = "br-lan" ];then
                tmp=$(ip_add_1 "${g_brlan_ip_buff}")
                set_br_lan_ip "${tmp}"
                ping_one_ip "${g_brlan_ip_buff}"
                set_br_lan_ip "${g_brlan_ip_buff}"

            elif [ "${result}" = "br-lan:0" ]; then
                tmp=$(ip_add_1 "${g_brlan0_ip_buff}")
                set_br_lan0_ip "${tmp}"
                ping_one_ip "${g_brlan0_ip_buff}"
                set_br_lan0_ip "${g_brlan0_ip_buff}"  

            fi

        else
            #单个IP
            ping_one_ip "${ip}"
        fi

    else
        #echo "not same"     
        #判断是IP地址还是网段
        ip=${ipAndMask%/*}
        tmp=$(echo "${ip}" | cut -d . -f 4)
        if [ 0 -eq "${tmp}" ];then
            #网段
            #不在同一个网段，将br_lan:0改为目的network.1
            ip=$(ip_add_1 "${network}")
            set_br_lan0_ip "${ip}"

            ping_part_ip "${ipAndMask}"

            #将brlan0 改为network.2   ping.1
            br_lan0_ip=$(ip_add_1 "${network}")
            br_lan0_ip=$(ip_add_1 "${br_lan0_ip}")
            set_br_lan0_ip "${br_lan0_ip}"
            ping_one_ip "${ip}"

        else
            #单个IP
            tmp=$(ip_add_1 "${ip}")
            set_br_lan0_ip "${tmp}"
            ping_one_ip "${ip}"
        fi

        #将br_lan:0恢复成原来的IP地址
        set_br_lan0_ip "${g_brlan0_ip_buff}"
    fi

    echo
           
}

#-------------------------main---------------------------------------
[ $# = 0 ] && {
    usage
    exit 1
}

#存储LAN口  IP地址
g_brlan0_ip_buff=$(ifconfig br-lan:0 | grep -w inet | awk '{print $2}' | cut -d :  -f 2)
g_brlan_ip_buff=$(ifconfig br-lan | grep -w inet | awk '{print $2}' | cut -d :  -f 2)
g_fifo_path="/tmp/scan.fifo"    #fifo路径
g_process_max=50               #最大进程数

while getopts 'has:' option; 
do
   case "${option}" in
       a)
            #按Ctrl+c退出时将LAN口 IP还原
            trap 'set_br_lan0_ip ${g_brlan0_ip_buff};
                  set_br_lan_ip ${g_brlan_ip_buff}; 
                  exit 1' INT 

            #echo "ping all ip address"
            ping_all_ip
            exit 0
       ;;
       #r)
       #     set_br_lan0_ip "192.168.58.1"
       #     echo "set br-lan:0 ip 192.168.58.1"
       #     exit 0
       #;;
       h)
            usage
            exit 1
       ;;
       s)
            shift
           
            #清除文件
            [ -e "${g_save_file}" ] && {
                #echo "clean recorde"
                rm ${g_save_file}
            }

            #按Ctrl+c退出时将LAN口 IP还原
            trap 'set_br_lan0_ip ${g_brlan0_ip_buff};
                  set_br_lan_ip ${g_brlan_ip_buff}; 
                  exit 1' INT

            g_ip_mask_list=$*
            for ipAndMask in ${g_ip_mask_list}
            do
                echo
                echo
                echo "please waite"
                echo "${ipAndMask}..."
                find_ip "${ipAndMask}"
                
            done    
       ;;
       ?)
            #echo "default (none of above)"
       ;;
   esac
   
done




