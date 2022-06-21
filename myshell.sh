#!/bin/sh


echoName(){
	echo $name
}

#变量
name="global yinwenfeng" 
echo ${name}

#只读变量,readonly将name变量变为只读 readonly不能修改， 只能注销当前shell才可以取消
#readonly name

#删除变量 将name变量删除
unset name 

#获取字符串长度 #
name="global yinwenfeng"
echo ${#name}

#提取字符串
#bash
#echo ${name:1:4}

#dash
#echo ${name#global}
#unset name

#传递参数
echo "参数0 $0"
echo "参数1 $1"
echo "参数2 $2"

#函数调用
echoName

:<<!
写在同一行的语句要用;分隔开
[  ]表示条件测试 '['后面 和']'起那面都要加空格
判断不支持浮点值

文件测试
[ -b FILE ] 		存在且FILE为块文件返回真
[ -e FILE/DIR ] 	指定的文件或目录存在返回真

字符串测试
[ -n STRING ] 		如果STRING的长度非零则返回为真，即非空是真 
!
if [ -d /dev/usb ]; then
	echo "存在"
else
	echo "不存在"
fi



#local用于局部变量申明
mylocal(){
	local name="local yinwenfeng"
	echo $name
}
mylocal

echo $name

#``执行指令
list=`ls`
echo $list

#awk指令
awkCmd(){
	echo ""
	echo "awk指令"
	local fileName="test.txt"
	local cotent
	
	#如果fileName存在
	if [ -e $fileName ];then {
		echo "$fileName exit"
		content=`awk '{print $1,$4}' $fileName`
		echo $content
	}
	else {
		echo "$fileName is not exit"
	}
	fi
}

awkCmd

:<<!
Shell 函数的返回值只能是一个介于 0~255 之间的整数，其中只有 0 表示成功，其它值都表示失败。
如果函数体中没有 return 语句，那么使用默认的退出状态，也就是最后一条命令的退出状态。
!

#计算数组长度
func_array_len(){
	if [ 1 ]; then
		#获取数组长度
		local array=(1 2 3)
		echo ${#array[*]} #输出结果： 3
	fi
}

func_array_len

#for

