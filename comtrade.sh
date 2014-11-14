#!/bin/bash

#cset="76 124"			#贸易国参数集合
cset="76 124 156 251 392 410 643 699 826 842"
re=$1
ti=$2
HOME=`pwd`
otop="data"
ypath=$HOME/$otop/$re/$ti

filed=${re}_${ti}
filea=${re}_${ti}
filep=${re}_${ti}_p

#=========去表头\选字段\\排序\有效性核对\填零
function checkdata()
{
	tmp=${1}.e
	sed '1d' ${1} | sed 's/\".*\"/product/g' | sed 's/\/\/.*,[0-9]+,/,5,/g'| awk -F "," '{ printf "%d %s\n",$15,$21}' | column -t -s "," > $tmp
	sort -n $tmp -o $tmp
#检查金额字段是否为数值,如不是则退出程序
	awk '
		$2!~/^[0-9]+$/{
			print FILENAME "\t line" NR ":" $1 " " $2 " Data validation error\n"
				exit 1
		}' $tmp	

#1-99,如某类别缺失,则补全,并把value置0
#seq 1 99 >list
	seq 1 99 | join -a 2 $tmp - > $tmp.tmp
	awk 'NF==2{print $1" "$2}NF==1{print $1" 0"}' $tmp.tmp >$tmp
	rm $tmp.tmp
}


#####
#	Parameter:$1 report 
#	Parameter:$2 parter
# 函数生成report和parter之间的Import/Export%的表单  $1_$2_2013.t
function trimdata()
{
	import=$1_$2
	checkdata	${import}
	echo "$1 Import $2 Total:$(awk '{t+=$2}  END {print t}' ${import}.e)"

	exp=$2_$1
	checkdata	${exp}
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

#__________________________________Programme Start Here
if [ 2 != $# ]; then
	echo "Usage $0 country time"
	exit	1
fi


#[ -f ${re} ] && mv ${re} ${re}.old

echo "Download import trade date of ${re}"
for p in $(echo $cset)
do
#	if [ ${re} == ${p} ] ; then
#			continue
#	fi
	target=${HOME}/${otop}/${re}/${ti}/${p}
	mkdir -p ${target}
	cd ${target}
	file="${re}_${p}"
	filex="${p}_${re}"
	#cc=AG2取两位分类代码 cc=AG1取一位代码,以此类推,最大6位
	urlim=http://comtrade.un.org/api/get\?freq\=A\&ps\=${ti}\&r\=${re}\&p\=${p}\&rg\=1\&head=m\&fmt\=csv
	urlex=http://comtrade.un.org/api/get\?freq\=A\&ps\=${ti}\&r\=${p}\&p\=${re}\&rg\=2\&head=m\&fmt\=csv
	echo "Deal ${p} $ti"
	if [ -f ${file} ] && [ -f ${filex} ]
	then
		echo "Data file exist"
	else
		sleep 2
		echo "Import $urlim"
		curl ${urlim} -o ${file}
		sleep 2
		echo "Export $urlex"
		curl ${urlex} -o ${filex}
	fi	
	trimdata  ${re} ${p} 
	cd -
done

#将某国对各国进出口数据整合成总表
cd ${HOME}/${otop}
[ -f ${filea} ] && rm ${filea}
touch ${filea}

for p in $(echo $cset)
do
	if [ -f ${ypath}/${p}/${re}.${p} ]
		then
		join -a 2 ${filea} ${ypath}/${p}/${re}.${p} >  tmp
		mv tmp ${filea}
	fi
done
echo "=========================Total Table====================== "
column -t ${filea}

sed -i '26,$d' $filea

#将百分比提取出单独成表,以便R使用 (NR <26 只取农业分类部分)
awk 'NR<26{
	for(i=1;i<=NF;i=i+3) {
		printf "%d ",$i
	}
	printf "\n"
}' ${filea} |column -t >${filep}
echo "=========================Total Percent====================== "
cat ${filep}
#R --slave --vanilla --file=../z.R --args ${re} > R.out
#cd ${HOME}/$otop
R --vanilla --file=${HOME}/z.R --args ${filea} $filep 

echo "------------------Finished"
