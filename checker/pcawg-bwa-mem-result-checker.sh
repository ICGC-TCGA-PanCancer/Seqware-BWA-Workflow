#!/bin/bash

normal_bam1=$1
normal_bam2=$2
unmapped_bam1=$3
unmapped_bam2=$4
normal_bai1=$5
normal_bai2=$6
unmapped_bai1=$7
unmapped_bai2=$8
normal_metrics1=$9
normal_metrics2=${10}
unmapped_metrics1=${11}
unmapped_metrics2=${12}



function check_md5 {
	md5_1=`md5sum $1 | cut -d' ' -f1`
	md5_2=`md5sum $2 | cut -d' ' -f1`
	if [ "$md5_1" != "$md5_2" ]
	then
		echo 0
		return
	fi
	echo 1
}

flag=0

if [ $(check_md5 <(/usr/bin/samtools view -f 64 $normal_bam1) <(/usr/bin/samtools view -f 64 $normal_bam2)) -eq 0 ];then echo "overall: false" > log.txt;echo "mismatch result found in "$normal_bam2 >> log.txt;flag=1;fi
if [ $(check_md5 <(/usr/bin/samtools view -f 64 $unmapped_bam1) <(/usr/bin/samtools view -f 64 $unmapped_bam2)) -eq 0 ];then echo "overall: false" > log.txt;echo "mismatch result found in "$unmapped_bam2 >> log.txt;flag=1;fi
if [ $(check_md5 <(cat $normal_bai1) <(cat $normal_bai2)) -eq 0 ];then echo "overall: false" > log.txt;echo "mismatch result found in "$normal_bai2 >> log.txt;flag=1;fi
if [ $(check_md5 <(cat $unmapped_bai1) <(cat $unmapped_bai2)) -eq 0 ];then echo "overall: false" > log.txt;echo "mismatch result found in "$unmapped_bai2 >> log.txt;flag=1;fi
if [ $(check_md5 <(cat $normal_metrics1) <(cat $normal_metrics2)) -eq 0 ];then echo "overall: false" > log.txt;echo "mismatch result found in "$normal_metrics2 >> log.txt;flag=1;fi
if [ $(check_md5 <(cat $unmapped_metrics1) <(cat $unmapped_metrics2)) -eq 0 ];then echo "overall: false" > log.txt;echo "mismatch result found in "$unmapped_metrics2 >> log.txt;flag=1;fi

touch log.stdout
touch log.stderr
if [ $flag -eq 0 ]
then
	echo "{\"overall\": true}" > log.stdout
        exit 0
else
	echo "{\"overall\": false}" >> log.stderr
        exit 1
fi
