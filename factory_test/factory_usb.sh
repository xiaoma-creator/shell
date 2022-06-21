#. factory_usb.sh 1 只对一个分区进行测试
g_only_one_part=${1:-0} 


is_mount(){
	local dev=$1
	local mnt=$2
    
    echo "${dev} ${mnt}" 
    
	awk -vd=$dev -vm=$mnt -vr=1 '$1==d && $2==m {print; r=0} END {exit r}' /proc/mounts 
}

mount_check(){
	local dev=$1
	local mnt=$2

	is_mount $dev $mnt >/dev/null || {
		echo "not_mounted: $mnt"
		return 1
	}
}

log=
log(){
	if [ "$log" == "verbose" ]; then
		cat
	else
		cat >/dev/null
	fi
}

g_dev_sda_list=""
g_mnt_sda_list=""

test_read_write(){
	#time -f '%e'
	local t1 t2 rt
	#local time size speed
	local file_i=$1
	local file_o=$2
	local count=${3:-100}
	local file=$file_o
    
	[ "$file_o" == "/dev/null" ] && file=$file_i

	echo 3 >/proc/sys/vm/drop_caches
	t1=`date +%s`
	dd if=$file_i of=$file_o bs=4M count=$count; rt=$?
	t2=`date +%s`
	sync

	time=$((t2-t1))
	size=`du -am $file | awk '{print $1}'`
	speed=`awk -vs=$size -vt=$time 'END {printf "%.2f\n", s/t}' /dev/null`

	[ $rt -eq 0 ] || echo "write error: $rt"
	echo
	echo " file: $file"
	echo " size: $size MB"
	echo " time: $time sec"
	echo "speed: $speed MB/s"
    echo
}

test_verify(){
	#md5sum /mnt/mmcblk0/test.w
	local file=$2
	local md5=$1
	local t1 t2
    
    echo $1

	[ "$1" == "fresh" ] && echo 3 >/proc/sys/vm/drop_caches
	t1=`date +%s`
	echo "$md5  $file" | md5sum -c; rt=$?
	t2=`date +%s`

	time=$((t2-t1))
	size=`du -am $file | awk '{print $1}'`
	speed=`awk -vs=$size -vt=$time 'END {printf "%.2f\n", s/t}' /dev/null`

	echo
	echo " file: $file"
	echo " size: $size MB"
	echo " time: $time sec"
	echo "speed: $speed MB/s"
	echo 
    echo

	if [ $? -eq 0 ]; then
		echo "data verify: ok"
	else
		echo "data verify: fail"
	fi
}

#显示usb分区信息
show_usb_part_info(){
    local usbDev=${g_dev_sda_list}
        
    if [ -n "${usbDev}" ]; then
        #usbDev字符串长度非0
        printf "%-16s %-8s %-8s %-16s %-16s\n" "Device Boot" "Size" "Used" "Available" "System"
        
        for usbPartDev in ${usbDev}
        do
            #devBoot    size    used    Available    System
            local size=`df -h | grep ${usbPartDev} | awk '{print $2}'`
            local used=`df -h | grep ${usbPartDev} | awk '{print $3}'`
            local available=`df -h | grep ${usbPartDev} | awk '{print $4}'`
            local system=`fdisk | grep ${usbPartDev} | awk '{print $6,$7}'`
            
            printf "%-16s %-8s %-8s %-16s %-16s\n" \
                "${usbPartDev}"\
                "${size}"\
                "${used}"\
                "${available}"\
                "${system}"
        done   
        echo
	else
		echo "Usb device is not exist"
		return 1
	fi
}

#检测U盘信息
usb_detect(){	
	if [ -b /dev/sda ]; then
		local size=`awk '{printf "%.1f\n", $1/1024/2/1024}' /sys/block/sda/size`
		local vendor=`cat /sys/block/sda/device/vendor`
		local model=`cat /sys/block/sda/device/model`
		
		echo "usb-storage found:"
		echo "   dev: /dev/sda"
		[ -n "${vendor}" ] && \
		echo "vendor: ${vendor}"
		[ -n "${model}" ] && \
		echo " model: ${model}"
		echo "  size: $size GB"
		echo
        
		g_dev_sda_list=`cat /proc/mounts  | grep '/dev/sda' | awk '{print $1}'`
		g_mnt_sda_list=`cat /proc/mounts  | grep '/dev/sda' | awk '{print $2}'`
			
		#显示usb分区信息
        echo "Part Infomation:"
		show_usb_part_info
		
		return 0
	else
		echo "error: no usb-storage found"
		return 1
	fi
}

usb_is_detected(){
    [ -n "${g_dev_sda_list}" ] || {
        echo "Please use usb_detect to get usb information"
        echo 
        return 1 
    }
    
    [ -n "${g_mnt_sda_list}" ] || {
        echo "Please use usb_detect to get usb information"
        echo
        return 1
    }
}

#检测U盘是否挂载
usb_mount(){ 
    usb_is_detected
    if [ $? != 0 ];then
        return 1
    fi
        
    local devIndex=0
    local mntIndex=0
    
    #遍历g_dev_sda_list和g_mnt_sda_list，检测是否挂载
    for dev in ${g_dev_sda_list}
    do
        mntIndex=0
        devIndex=`expr ${devIndex} + 1`
        
        for mnt in ${g_mnt_sda_list}
        do
            mntIndex=`expr ${mntIndex} + 1`
            if [ $mntIndex == $devIndex ]; then
                is_mount ${dev} ${mnt} >/dev/null && {
                    echo "mount ok: ${mnt}"
                    break
                } 
                
                echo "mount fail: ${dev}"
                break
            fi
        done
    done
}

#卸载分区
usb_remove(){  
    local mntIndex=0
    local devIndex=0
    
    #遍历g_dev_sda_list和g_mnt_sda_list
    for dev in ${g_dev_sda_list}
    do
        mntIndex=0
        devIndex=`expr ${devIndex} + 1`
        
        for mnt in ${g_mnt_sda_list}
        do
            mntIndex=`expr ${mntIndex} + 1`
            if [ $mntIndex == $devIndex ]; then
                umount ${dev}
                is_mount $dev $mnt  >/dev/null || {
                    echo "remove_ok: /dev/sda"
                    break;
                }
                echo "remove_fail: /dev/sda"
                break
            fi
        done
        
        #是否只测试一个分区
        [ ${g_only_one_part} == 1 ] && break
    done
}

#写速度测试
usb_test_write(){
    usb_is_detected
    if [ $? != 0 ];then
        return 1
    fi
    
    local mntIndex=0
    local devIndex=0
    
    #遍历g_dev_sda_list和g_mnt_sda_list
    for dev in ${g_dev_sda_list}
    do
        mntIndex=0
        devIndex=`expr ${devIndex} + 1`
        
        for mnt in ${g_mnt_sda_list}
        do
            mntIndex=`expr ${mntIndex} + 1`
            if [ $mntIndex == $devIndex ]; then
                echo "${mnt} write testing..  (about 10sec)"
                mount_check ${dev} ${mnt} || break  #检测是否挂载
                
                test_read_write /dev/zero ${mnt}/test.w 25
                break
            fi
        done
        
        #是否只测试一个分区
        [ ${g_only_one_part} == 1 ] && break
    done
}

#读速度测试
usb_test_read(){
    usb_is_detected
    if [ $? != 0 ];then
        return 1
    fi
    
    local mntIndex=0
    local devIndex=0
    
    #遍历g_dev_sda_list和g_mnt_sda_list
    for dev in ${g_dev_sda_list}
    do
        mntIndex=0
        devIndex=`expr ${devIndex} + 1`
        
        for mnt in ${g_mnt_sda_list}
        do
            mntIndex=`expr ${mntIndex} + 1`
            
            if [ $mntIndex == $devIndex ]; then
                echo "${mnt} read testing..  (about 5sec)"
                mount_check ${dev} ${mnt} || break  #检测是否挂载
                
                #检测test.w文件是否存在
                local file=${mnt}/test.w
                [ -f "$file" ] || {
                    echo "error: test file not exist  $file"
                    #return 1
                    break;
                }
                
                test_read_write $file /dev/null 25              
                break
            fi
        done
        
        #是否只测试一个分区
        [ ${g_only_one_part} == 1 ] && break
    done
}

#文件校验
usb_test_verify(){
    usb_is_detected
    if [ $? != 0 ];then
        return 1
    fi
    
    local mntIndex=0
    local devIndex=0
    
    #遍历g_dev_sda_list和g_mnt_sda_list
    for dev in ${g_dev_sda_list}
    do
        mntIndex=0
        devIndex=`expr ${devIndex} + 1`
        
        for mnt in ${g_mnt_sda_list}
        do
            mntIndex=`expr ${mntIndex} + 1`
            
            if [ $mntIndex == $devIndex ]; then
                echo "usb data verfing.. (about 5sec)"
                mount_check ${dev} ${mnt} || break  #检测是否挂载
                
                test_verify 2f282b84e7e608d5852449ed940bfc51 ${mnt}/test.w                 
                
                break
            fi
        done
        
        #是否只测试一个分区
        [ ${g_only_one_part} == 1 ] && break
    done
}

#清除测试文件
usb_test_clean(){
    for mnt in ${g_mnt_sda_list}
    do
        echo "rm usb_test file in ${mnt}"
        rm -f ${mnt}/test.w    
    done
}


[ "${0##*/}" == "factory_usb.sh" ] && [ -n "$1" ] && "$@"

