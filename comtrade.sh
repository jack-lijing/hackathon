#!/bin/bash

function checkdata()
{
	awk '$2!~/^[0-9]+$/{print FILENAME "\t line" NR ":" $1 " " $2 " Data validation error\n";exit 1}' $1	
}


#####
#	Parameter:$1 filename
#	Parameter:$2 report 
#	Parameter:$3 parter
# 函数生成report和parter之间的Import/Export%的表单  *.t
function trimdata()
{
	sed '1d' ${1}| sed 's/\".*\"/product/g' | sed 's/\/\/.*,[0-9]+,/,5,/g'| awk -F "," '{ print $7","$15 ","$21}' | column -t -s "," > ${1}.a
	checkdata	${1}.a
	cat ${1}.a | awk '{if($1==1) { t+=$3; print $2" " $3}}' | sort -n >${1}.i
	echo "Import Total:$(awk '{t+=$2}  END {print t}' ${1}.i)"
	cat ${1}.a | awk '{if($1==2) { t+=$3; print $2" " $3}}' | sort -n >${1}.e
	echo "Export Total:`awk '{t+=$2}  END {print t}' ${1}.e`"

	#数据聚合，同一类别归入同一大类中
	[ -e ${1}.ic ] && rm ${1}.ic
	[ -e ${1}.ec ] && rm ${1}.ec
	for c in $(seq 1 9)
	do
		cat ${1}.i | grep "^0${c}" | awk -v c=${c} -v t=0 '{t+=$2} END {print c " " t}' >>${1}.ic
		cat ${1}.e | grep "^0${c}" | awk -v c=${c} -v t=0 '{t+=$2} END {print c " " t}' >>${1}.ec
	done
	join ${1}.ic ${1}.ec | awk -v p=${3} 'BEGIN { printf"T\tIm\tEx\t%s\n", p }  $3!=0{p=$2/$3*100; printf"%s\t%s\t%s\t%2.1f\n",$1,$2,$3,p} $3==0{print $1"\t"$2"\t"$3"\t0.0"}' |tee  ${1}.t
	#	ls | egrep '\.[aiec]' | xargs rm
}

#__________________________________Programme Start Here
if [ 1 != $# ]; then
	echo "Usage $0 country"
	exit	1
fi

re=$1
od=data
mkdir -p ${od}				#不存在则创建data目录, 存放原始数据

cd ${od}
[ -f ${re} ] && mv ${re} ${re}.old

echo "Download import trade date of ${re} \n"
for p in 76 124 156 251 643 699 826 842
do
	if [ ${re} == ${p} ] ; then
			continue
	fi

	file="${re}_${p}_2013"
	url="http://comtrade.un.org/api/get\?type\=C\&freq\=A\&px\=HS\&ps\=2013\&r\=${re}\&p\=${p}\&rg\=all\&cc\=ALL\&head=M\&fmt\=csv"
	echo "Deal ${p}"
	echo "$url"
	if [ -f ${file} ]
	then
		echo "Data file exist"
	elif [ ${re} == ${p} ] ; then
		curl ${url} -o ${file}
	fi	
	trimdata ${file} ${re} ${p} 
done

#将各国数据整合成总表
[ -f ${re}.all ] && rm ${re}.all
touch ${re}.all

for p in 76 124 156 251 643 699 826 842
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
awk '{print $1" "$4" "$7" "$10" "$13" "$16" "$19" "$22"\t"}' ${re}.all | column -t > ${re}.p
echo "=========================Total Percent====================== "
cat ${re}.p
#R --slave --vanilla --file=../z.R --args ${re}.p > R.out

#mkdir -p ../output				#存放最终的输出结果
#cp ${re}.p ../output/
#echo "------------------Finished"
