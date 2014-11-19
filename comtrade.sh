#!/bin/bash

##	根据pt代码获取pt全名, 并替换{fileap}表头
function getptname()
{
         printf "类别 " > head
         for pt in $cset
         do
                 grep  "^$pt:" ${HOME}/country | awk -F ":" '{printf "%s ",$2 }' >> head
         done
         echo "平均%" >> head

	 tmp=`mktemp` 
	 sed '/ave/r head' ${ypath}/${filep} | sed '/ave/d' | tee ${tmp}
	 cp ${tmp} ${ypath}/${filep}
	 rm head
}

##
#获取re国家year 的 parter 列表
function getparter()
{
	re=$1
	year=$2
	url="http://comtrade.un.org/api/get?freq=A&ps=${year}&r=${re}&p=all&rg=1&fmt=csv"
#rm parter_o parter
	echo ">>>>>>>>>>>Download Parter ${year} : ${url} >>>>>>>>>>>>>"
	if [ -f ${ypath}/parter.tmp ] ;then
		echo "local file exit"
	else
		curl ${url} -o parter.tmp
		sed '1d' parter.tmp | sed 's/"[^"]*"/product/g' | sed 's/\/\/.*,[0-9]+,/,5,/g'| awk -F "," '{ printf "%d %s\n",$12,$21}' | column -t -s "," | sort -n -k 2 -r | awk '{print $1}' | grep -v '^0' | head -n 8 | sort -n | uniq >  parter
	fi
#rm parter.tmp
	sleep 2
}


#=========去表头\选字段\\排序\有效性核对  如果金融字段不为数字,则退出脚本
#输入参数:原始下载文件名    输出:输出.e 文件
function checkdata()
{
	tmp=${1}.e
	sed '1d' ${1} | sed 's/"[^"]*"/product/g' | sed 's/\/\/.*,[0-9]+,/,5,/g'| awk -F "," '{ printf "%d %s\n",$15,$21}' | column -t -s "," > $tmp
	sort -n $tmp -o $tmp
		#检查金额字段是否为数值,如不是则退出程序
	awk '
		$2!~/^[0-9]+$/{
			print FILENAME "\t line" NR ":" $1 " " $2 " Data validation error\n"
				exit 1
		}' $tmp	
}

#输入经过checkdata处理的文件,补全1-99分类
function fillzero()
{

	#1-99,如某类别缺失,则补全,并把value置0
	seq 1 99 | join -a 2 $1 - > ${1}.tmp
	awk 'NF==2{print $1" "$2}NF==1{print $1" 0"}' ${1}.tmp >$1
	rm ${1}.tmp
}


#####
#	Parameter:$1 report 
#	Parameter:$2 parter
# 函数生成report和parter之间的Import/Export%的表单  $1_$2_2013.t
#输出: re.pt文件
function trimdata()
{
	import=$1_$2
	checkdata	${import}
	fillzero	${import}.e		
	echo "$1 Import $2 Total:$(awk '{t+=$2}  END {print t}' ${import}.e)"

	exp=$2_$1
	checkdata	${exp}
	fillzero	${exp}.e		
	echo "$2 Export $1 Total:`awk '{t+=$2}  END {print t}' ${exp}.e`"

	#数据聚合.合并出口表和进口表,进行百分比计算
	join ${import}.e ${exp}.e | awk -v parter=${2} '
	BEGIN { printf"T\tIm\tEx\t%s\n", parter } 
	$3!=0 { per=$2/$3*100	
		printf"%s\t%s\t%s\t%d\n",$1,$2,$3,per 
	} 
	$2==0&&$3==0 {print $1"\t"$2"\t"$3"\t100"}
	$2!=0&&$3==0 {print $1"\t"$2"\t"$3"\t1000"}' | column -t | tee  ${1}.${2}
	#	ls | egrep '\.[aiec]' | xargs rm
}

#如果本地不存在数据文本,则下载 参数一:re	参数二:pt	参数三:time
function download()
{
	local re=$1
	local p=$2
	local ti=$3
	local target=${HOME}/${otop}/${re}/${ti}/${p}
	mkdir -p ${target}
	cd ${target}
	local file="${re}_${p}"
	local filex="${p}_${re}"
	#cc=AG2取两位分类代码 cc=AG1取一位代码,以此类推,最大6位
	local urlim=http://comtrade.un.org/api/get\?freq\=A\&ps\=${ti}\&r\=${re}\&p\=${p}\&rg\=1\&head=m\&fmt\=csv
	local urlex=http://comtrade.un.org/api/get\?freq\=A\&ps\=${ti}\&r\=${p}\&p\=${re}\&rg\=2\&head=m\&fmt\=csv
	echo "=============Deal ${p} ${ti}================"
	sleep 2
	if [ -f ${file} ] && [ -f ${filex} ]
	then
		echo " local Data file exist"
	else
		sleep 1
		echo "Import $urlim"
		curl ${urlim} -o ${file}
		sleep 1
		echo "Export $urlex"
		curl ${urlex} -o ${filex}
	fi
}


##获取re某年的parter数据
#输入参数:re  year
function getyear()
{
	local pt;
	local year=$2
	echo "Download import trade date of ${re} in ${year}"
	for pt in $cset
	do
		if [ ${re} == ${pt} ] ; then
			continue
		fi
		download ${re} ${pt} ${year}
		trimdata  ${re} ${pt} 
		cd -
	done
}

#######################################################################
#__________________________________Programme Start Here
if [ 2 != $# ]; then
	echo "Usage:$0 country year"
	echo "参数一:country 使用贸易国代码 "
	echo "参数二:year 使用年份(如2012),同时支持recent选项,表示最近五年"
	exit	1
fi
re=$1
ti=$2
HOME=`pwd`
otop="data"
rpath=${HOME}/${otop}/${re}

filea=${re}
filep=${re}_p

if [ $ti = "recent" ]
then
	yset="2013 2012 2011 2010 2009"
else
	yset=$ti	
fi

for year in $yset
do
	ypath=$HOME/$otop/$re/$year
	mkdir -p ${ypath}
	cd ${ypath}
	getparter ${re} ${year}
	cset=$(cat ${ypath}/parter)
	getyear ${re} ${year}
	
	#将某国对各国进出口数据整合成总表
	echo "======  Single Parter Finish, let Join them together ================"
	sleep 2
	cd ${ypath}
	[ -f ${filea} ] && rm ${filea}
	touch ${filea}

	for pt in $(echo $cset)
	{
		ptpath=${ypath}/$pt
		if [ -f ${ptpath}/${re}.${pt} ]
			then
			join -a 2 ${filea} ${ptpath}/${re}.${pt} >  tmp
			mv tmp ${filea}
		fi
	}
	echo "===================Generating  ${re} in ${year} Total Table====================== "

	#将百分比提取出单独成表,以便R使用 (NR <26 只取农业分类部分)
	sed -i '26,$d' $filea
	awk 'NR<26{
		for(i=1;i<=NF;i=i+3) {
			printf "%d ",$i
			}
			printf "\n"
		}' ${filea} |column -t >${filep}
	cd ${ypath}
	R --slave --vanilla --file=${HOME}/z.R --args ${filea} 2
	getptname
	column -t ${filep}
	R --slave --vanilla --file=${HOME}/z.R --args ${filep} 1
	echo "===============================${year} Finished ==========================="
done


if [ ${ti} = "recent" ]
then
      	echo "=========================Generating Years Average Picture==========================="
	cd ${rpath}
	recent=years
	[ -f ${recent} ] && rm ${recent}
	touch ${recent}
	for year in $yset
	do
		ypath=${rpath}/${year}
		awk -v y=${year} 'BEGIN {print "类别 " y } NR>1{print $1" "$NF}' ${ypath}/${filep} | \
			 join -a 2 ${recent} - > ${recent}.tmp 
		mv ${recent}.tmp ${recent}
	done
	R --slave --vanilla --file=${HOME}/z.R --args ${recent} 1
fi
