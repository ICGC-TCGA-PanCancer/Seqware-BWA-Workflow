#/bin/bash
cd $1
for i in `find . -type f`; do
	md5sum $i;
	if [[ "$i" == *bam ]]
	    then
	    LINES=`samtools view ${i} | wc -l`;
	    if [ $LINES = '0' ];  then echo there are no lines in the BAM file; exit 1; fi
	fi;
done
