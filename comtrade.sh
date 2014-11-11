#!/bin/bash

function checkdata()
{
	awk '$2!~/^[0-9]+$/{print FILENAME "\t line" NR ":" $1 " " $2 " Data validation error\n";exit 1}' $1	
}


#####
#	Parameter:$1 report 
#	Parameter:$2 parter
# 函数生成report和parter之间的Import/Export%的表单  $1_$2_2013.t
function trimdata()
{
	import=$1_$2_2013
	sed '1d' ${import}| sed 's/\".*\"/product/g' | sed 's/\/\/.*,[0-9]+,/,5,/g'| awk -F "," '{ print $15 ","$21}' | column -t -s "," > ${import}.i
	checkdata	${import}.i
	sort -n ${import}.i -o ${import}.i
	echo "$1 Import $2 Total:$(awk '{t+=$2}  END {print t}' ${import}.i)"

	exp=$2_$1_2013
	sed '1d' ${exp}| sed 's/\".*\"/product/g' | sed 's/\/\/.*,[0-9]+,/,5,/g'| awk -F "," '{ print $15 ","$21}' | column -t -s "," > ${exp}.e
	checkdata	${exp}.e
	sort -n ${exp}.e -o ${exp}.e
	echo "$2 Export $1 Total:`awk '{t+=$2}  END {print t}' ${exp}.e`"

	#数据聚合，同一类别归入同一大类中
	[ -e ${import}.ic ] && rm ${import}.ic
	[ -e ${exp}.ec ] && rm ${exp}.ec
	for c in $(seq 1 9)
	do
		cat ${import}.i | grep "^0${c}" | awk -v c=${c} -v t=0 '{t+=$2} END {print c " " t}' >>${import}.ic
		cat ${exp}.e | grep "^0${c}" | awk -v c=${c} -v t=0 '{t+=$2} END {print c " " t}' >>${exp}.ec
	done
	join ${import}.ic ${exp}.ec | awk -v p=${2} 'BEGIN { printf"T\tIm\tEx\t%s\n", p }  $3!=0{p=$2/$3*100; printf"%s\t%s\t%s\t%2.1f\n",$1,$2,$3,p} $3==0{print $1"\t"$2"\t"$3"\t0.0"}' | column -t | tee  ${import}.t
	rm ${import}.ic ${exp}.ec
	#	ls | egrep '\.[aiec]' | xargs rm
}

#__________________________________Programme Start Here
if [ 1 != $# ]; then
	echo "Usage $0 country"
	exit	1
fi

cset="76 124 156 251 392 410 643 699 826 842"
re=$1
od=data
mkdir -p ${od}				#不存在则创建data目录, 存放原始数据

cd ${od}
[ -f ${re} ] && mv ${re} ${re}.old

echo "Download import trade date of ${re}"
for p in $(echo $cset)
do
	if [ ${re} == ${p} ] ; then
			continue
	fi

	file="${re}_${p}_2013"
	filex="${p}_${re}_2013"
	urlim=http://comtrade.un.org/api/get\?freq\=A\&ps\=2013\&r\=${re}\&p\=${p}\&rg\=1\&head=m\&fmt\=csv
	urlex=http://comtrade.un.org/api/get\?freq\=A\&ps\=2013\&r\=${p}\&p\=${re}\&rg\=2\&head=m\&fmt\=csv
	echo "Deal ${p}"
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
done

#将某国对各国进出口数据整合成总表
[ -f ${re}.all ] && rm ${re}.all
touch ${re}.all

for p in $(echo $cset)
do
	file="${re}_${p}_2013"
	if [ -f ${file} ]
		then
		join -a 1 ${file}.t ${re}.all >  tmp
		mv tmp ${re}.all
	fi
done
echo "=========================Total Table====================== "
column -t ${re}.all
awk '{for(i=1;i<=NF;i=i+3) {printf "%d ",$i};printf "\n"}' ${re}.all |column -t >${re}.p
echo "=========================Total Percent====================== "
cat ${re}.p
#R --slave --vanilla --file=../z.R --args ${re}.p > R.out

#mkdir -p ../output				#存放最终的输出结果
#cp ${re}.p ../output/
#echo "------------------Finished"
