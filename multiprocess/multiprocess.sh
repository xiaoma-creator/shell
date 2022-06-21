#!/bin/ash
# shellcheck shell=dash

g_start_time=$(date +%s)        #脚本开始时间
g_fifo_path="/tmp/scan.fifo"    #fifo路径
g_process_max=50               #最大进程数

#创建有名管道
[ -f ${g_fifo_path} ] && rm ${g_fifo_path}
mkfifo ${g_fifo_path}

#创建文件描述符并关联到管道
exec 3<>${g_fifo_path}

#删除有名管道（文件描述符仍然可使用）
rm ${g_fifo_path}

#往管道塞钥匙
i=0
while [ $i -lt $g_process_max ]
do
    echo >&3
    i=$((i + 1))
done

i=0
while [ $i -lt 10000 ]
do
    read -u3            #获取钥匙
{                       #要在后台运行的指令放在  { }中， &表示后台运行
    sleep 1s            #
    echo "complete $i"  #
    echo >&3
}&                      #
    i=$((i + 1)) 
done

wait

g_end_time=$(date +%s)


echo "time use $((g_end_time - g_start_time))"