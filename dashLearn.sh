#!/bin/bash


#local 是不符合POSIX标准的

#提取字符串
func_get_string(){
    local string
	echo "func_get_string"
	string="hello world yinwenfeng"
	
	echo "${string#hello}"
	echo "${string%yinwenfeng}"
	
}
#func_get_string

#计数
#expr用于计算表达式
func_array(){
	local str="aaa bbb ccc"
	local count=0
	
	for content in ${str}
	do
        echo "${content}"
        count=$((count + 1))      
	done 
	echo "count = ${count}"
}
#func_array

#${a:b} 如果a没有设定，则取b为返回值
#${a:-b} 如果a没有设定或为空，则取b为返回值
func_set(){
    local count=${1:-"not set"}
    
    echo "${count}"
}

#func_set abc

# $(())  计算括号内表达式
#var1=$((1+2))
#echo "${var1}"

#var1=$((1<<2))
#echo "${var1}"

# [ -z string ] string长度为0 返回true
# [ -n string ] string长度不为0 返回true

:<<!
getopt用法
-o 短选项
-l 长选项
:  选项后面必须带参数
:: 选项后面的参数可有可无
-n getopt在解析命令行时，如果解析出错将会报告错误信息，
    getopt将使用该NAME作为报错的脚本名称。
-- 表示getopt命令自身的选项到此结束，后面的元素都是要被getopt解析的命令行参数

最常用的getopt解析方式
    getopt -o SHORT_OPTIONS -l LONG_OPTIONS -n "$0" -- "$@"
!
usage(){
   echo "Usage:  "
   echo "dashLearn <option>"
   echo
   echo "Parse command options."
   echo
   echo "options"
   echo " -a, --longa             display option a"
   echo " -b, --longb             display option b"
   echo " -c, --longc             display option c"
   echo " -h, --help              display this help and exit"     
   echo 
}

#无输入参数
[ $# = 0 ] && {
    usage
    exit 1
}

parameters=$(getopt -o ahb:c:: -l longa,longb,help,longc: -n "$0" -- "$@")
[ $? != 0 ] && exit 1   

eval set -- "$parameters"   # 将$parameters设置为位置参数
while true ; do             # 循环解析位置参数
    case "$1" in
        -a|--longa)         # 不带参数的选项-a或--longa
            echo "option a, no arguments"
            shift 
            ;;
        -b|--blong)         # 带参数的选项-b或--longb
            echo "option b, arguments is ${2}"
            shift 2
            ;;    
        -c|--clong)         # 参数可选的选项-c或--longc
            case "$2" in   
                "")     # 没有给可选参数
                    echo "option c, no arguments"; 
                    shift 2
                    ;;  
                *)      # 给了可选参数
                    echo "option c, arguments is ${2}"
                    shift 2
                    ;;                                   
            esac
            ;;
        -h|--help)
            usage
            exit 1
            ;;
        --)                 # 开始解析非选项类型的参数，break后，它们都保留在$@中
            #echo "none-option paragram $*";
            shift
            break 
            ;;       
        *) 
            echo "wrong"
            exit 1
            ;;
    esac
done


#g_network_addr=""                       #网络号
##获取网络号，存储到g_network_addr
#get_network_addr(){
#    local IPMask=$1
#
#    #验证合法性 
#    if ! is_ip_and_mask "$IPMask"; then
#        return 1
#    fi
#
#    #提取IP和掩码
#    IPAddr=$(echo "$IPMask" | cut -d/ -f1)
#    IPType_1=$(echo "$IPAddr" | cut -d. -f1)
#    IPType_2=$(echo "$IPAddr" | cut -d. -f2)
#    IPType_3=$(echo "$IPAddr" | cut -d. -f3)
#    IPType_4=$(echo "$IPAddr" | cut -d. -f4)
#    mask=$(echo "$IPMask" | cut -d/ -f2)
#    #echo "IP address is ${IPType_1}.${IPType_2}.${IPType_3}.${IPType_4} , Mask is $mask ."
#
#    #IP地址16进制形式
#    IPHex_1=$((IPType_1<<24))
#    IPHex_2=$((IPType_2<<16))
#    IPHex_3=$((IPType_3<<8))
#    IPHex_4=$((IPType_4))
#    IPHex=$((IPHex_1+IPHex_2+IPHex_3+IPHex_4))
#
#    #生成16进制掩码
#    #declare -i strMask1=0xffffffff
#    strMask1=0xffffffff
#    strMask1=$((strMask1<<(32-mask) & 0xffffffff))
#
#    #网络号
#    networkAddr=$((IPHex & strMask1))
#
#    #将16进制网络号转化为10进制IP地址
#    IPHex_1=$((networkAddr>>24 & 0x000000ff))
#    IPHex_2=$((networkAddr>>16 & 0x000000ff))
#    IPHex_3=$((networkAddr>>8 & 0x000000ff))
#    IPHex_4=$((networkAddr & 0x000000ff))
#    #echo -e "Network Address   : ${IPHex_1}.${IPHex_2}.${IPHex_3}.${IPHex_4}"
#    g_network_addr=${IPHex_1}.${IPHex_2}.${IPHex_3}.${IPHex_4}
#    #echo "${g_network_addr}"
#}