#--------------------------------------------------------------------
# Copyright 2020. Bioinformatic and Genomics Lab.
# Hanyang University, Seoul, Korea
# Coded by Jang-il Sohn (sohnjangil@gmail.com)
#--------------------------------------------------------------------  

VERSION="ETCHING_v1.0.1 (released 2020.09.05)\n"

#############################
#
# Help message
#

USAGE="
$VERSION\n
Usage: etching [options] -i exam.conf [options]\n
\n
Example)\n
\$ etching -i exam.conf -p test_out -t 30 -w workdir -T P -L 150 -P 0.5 -A -R\n
\n
[Required]\n
-i (string)  \tConfig file\n
\n
[General options]\n
-p (string)  \tPrefix of output [etching]\n
-t (int)     \tNumber of threads [8]\n
-d (string)  \t/path/to/etching [none]\n
           \t\tUse this if you need to specify it.\n
-w (string)  \tWorking directory [./working]\n
-h\t\tPrint this message\n
\n
[READ FILTER]\n
-T (stiring) \tW for WGS, P for Panel [W]\n
-K (int)     \tK-mer frequency cut-off for removing \n
           \t\tsequencing error in etching_filter [automatic]\n
-L (int)     \tRead length [100]\n
\n
[SV CALLER]\n
-P (double)  \tTumor purity [0.75]\n
-I (int)     \tInsert-size [500]\n
-O (string)  \tRead-orientation FR or RF. [FR]\n
-A         \t\tUse all split-reads [None]\n
           \t\tThis option increases recall. However,\n
           \t\tlots of folse-positives also can be generated.\n
\n
[SV SORTER]\n
-R         \t\tRandom Forest in scoring [default]\n
-X         \t\tXGBoost in scoring\n
-C (double)  \tCut-off of false SVs [0.4]\n
-m (string)  \tPath to ETCHING machine learning model [None]\n
           \t\tUse this if you want to specify the path to\n
           \t\tmachine learning models.\n
\n
[About ETCHING]\n
-h         \t\tPrint this message\n
-v         \t\tPrint version\n
\n
Contact:\n\tJang-il Sohn (sohnjangil@gmail.com)\n\tJin-Wu Nam (jwnam@hanyang.ac.kr)\n
"

#####################################

if [ $# -lt 1 ]
then
    echo -e $USAGE
    exit -1
fi


CONF=

PREFIX=etching
THREADS=8
DIR=
WORKDIR=working

DATATYPE=W
KMERCUTOFF=
READLENGTH=100

ALLSPLIT=
PURITY=0.75
INSERTSIZE=500
ORIENT=FR

ALGOR=
ALGOR_R=0
ALGOR_X=0
CUTOFF=0.4

while [ "$1" != "" ]; do
    case $1 in
        -i | --config )  shift
            CONF=$1
            ;;
        -p | --prefix )  shift
            PREFIX=$1
            ;;
        -t | --threads ) shift
	    THREADS=$1
            ;;
        -d | --directory ) shift
	    DIR=$1
            ;;
        -w | --work_dir ) shift
	    WORKDIR=$1
            ;;

        -T | --data_type ) shift
	    DATATYPE=$1
            ;;
        -K | --kmer_cutoff ) shift
	    KMERCUTOFF=$1
            ;;
        -L | --read_length ) shift
	    READLENGTH=$1
            ;;

        -A | --all_split )
	    ALLSPLIT="-A"
            ;;
        -P | --purity ) shift
	    PURITY=$1
            ;;
        -I | --insert ) shift
	    INSERTSIZE=$1
            ;;
        -O | --orientation ) shift
	    ORIENT=$1
            ;;

        -R | --random_forest )
	    ALGOR_R=1
            ;;
        -X | --xgboost )
	    ALGOR_X=1
            ;;
        -C | --cutoff ) shift
	    CUTOFF=$1
            ;;
        -m | --path_to_machine_learning_model ) shift
	    ML_PATH=$1
            ;;

        -h | --help ) echo -e $USAGE
            exit
            ;;

        -v | --help ) echo -e $VERSION
            exit
            ;;
    esac
    shift
done

#############################
#
# ETCHING starts here
#

echo "[ETCHING START]"
DATE="[$(date)]"
echo ${DATE}

#############################
#
# Checking files and options
#

# Setting algorithm parameter
if [ ${ALGOR_R} == 1 ] && [ ${ALGOR_X} == 1 ]
then
    echo "ERROR!!! -R and -X can not used together."
    echo "-----------------------------------------"
    echo -e $USAGE
    exit -1
fi

# Setting default algorithm
if [ ${ALGOR_R} == 0 ] && [ ${ALGOR_X} == 0 ]
then
    ALGOR_R=1
    #ALGOR_X=1
fi

if [ ${ALGOR_R} == 1 ]
then 
    ALGOR="-R"
fi

if [ ${ALGOR_X} == 1 ]
then 
    ALGOR="-X"
fi

# Setting sequencing data type
if [ ! ${DATATYPE} == "W" ] && [ ! ${DATATYPE} == "P" ]
then
    echo "ERROR!!! -T must be used with W or P."
    echo "---------------------------"
    echo -e $USAGE
    exit -1
fi

# Check paths
if [ ${#ETCHING_ML_PATH} == 0 ] && [ ${#ML_PATH} == 0 ]
then
    echo "ERROR!!!"
    echo "You need to set"
    echo " export ETCHING_ML_PATH=/path/to/etching/ML_model"
    echo "or run with the option"
    echo " -m /path/to/etching/ML_model"
    exit -1
fi

CHECK_PATH=$ETCHING_ML_PATH
if [ ${#ML_PATH} != 0 ]
then
    CHECK_PATH=$ML_PATH
fi

TMP="rf"
if [ $ALGOR == "-X" ]
then
    TMP="xgb"
fi

for i in [1..10]
do
    if [ ! -f ${CHECK_PATH}/etching_${TMP}_${i}.sav ]
    then
	echo "ERROR!!!"
	echo "No model files in ${CHECK_PATH}"
	echo "-------------------------------"
	exit -1
    fi
done


#############################
#
# get config
#

if [ ${#CONF} == 0 ]
then
    echo "Please input config file."
    echo "-------------------------"
    echo -e $USAGE
    exit -1
fi


#############################
#
# CHECKING REQUIRES
#

if [ ${#DIR} != 0 ]
then
    DIR=${DIR}/
    DIR_OPT="-d ${DIR}"
fi


for i in etching_conf_parse etching_filter estimate_coverage etching_caller etching_sorter etching_fg_identifier kmer_filter read_collector
do
    CHECK=$(which ${DIR}${i} 2> err )
    rm err
    if [ ${#CHECK} == 0 ]
    then
	echo "ERROR!!!"
	echo "ETCHING was not install properly."
	exit -1
    fi
done



for i in etching_caller etching_sorter etching_fg_identifier read_collector
do
    CHECK=$(${i} 2> err )
    if [ ${#CHECK} == 0 ]
    then
        echo "ERROR!!!: Shared library was not installed."
	echo "Please set LD_LIBRARY_PATH=/path/to/etching/lib:$LD_LIBRARY_PATH"
	echo "----------------------------------------------------------------"
        cat err
	rm err
        exit -1
    fi
done


for i in kmc kmc_tools kmc_dump
do
    CHECK=$(which ${i} 2> err )
    rm err
    if [ ${#CHECK} == 0 ]
    then
	echo "ERROR!!!"
	echo "KMC3 was not install properly."
	exit -1
    fi
done


MAPPER=$(grep -v "#" ${CONF} | awk '{if($1=="mapper") print $2}' )
SAMTOOLS=$(grep -v "#" ${CONF} | awk '{if($1=="samtools") print $2}' )


if [ ${#MAPPER} == 0 ]
then
    MAPPER="bwa mem"
    CHECK=$(which $MAPPER 2> err )
    rm err
    if [ ${#CHECK} == 0 ]
    then
	echo "ERROR!!!"
	echo "bwa was not install"
	exit -1
    fi
else
    CHECK=$(grep -v "#" ${CONF} | awk '{if($1=="mapper") print $2}' | grep bwa)
    if [ ${#CHECK} != 0 ]
    then
	MAPPER="${CHECK}"
	CHECK=$(which $MAPPER 2> err )
	rm err
	if [ ${#CHECK} == 0 ]
	then
	    echo "ERROR!!!"
	    echo "bwa was not install"
	    exit -1
	fi
    else
	CHECK=$(grep -v "#" ${CONF} | awk '{if($1=="mapper") print $2}' | grep minimap2)
	if [ ${#CHECK} != 0 ]
	then
            MAPPER=$CHECK
	    CHECK=$(which $MAPPER 2> err )
	    rm err
	    if [ ${#CHECK} == 0 ]
	    then
		echo "ERROR!!!"
		echo "minimap2 was not install"
		exit -1
	    fi
	else
            echo "ERROR!!!"
	    echo "Mapper must be one of bwa or minimap2 in $CONF file."
            exit -1
	fi
    fi
fi




if [ ${#SAMTOOLS} == 0 ]
then
    SAMTOOLS=samtools
fi

CHECK=$(which $SAMTOOLS 2> err )
rm err
if [ ${#CHECK} == 0 ]
then
    echo "ERROR!!!"
    echo "samtools was not installed"
    exit -1
fi


#######################################################################################
#
# check working directory
#
if [ ! -d $WORKDIR ]
then
    echo "mkdir $WORKDIR"
    mkdir $WORKDIR
else
    #rm -rf $WORKDIR/*
    echo "WARNING!!! There is the working directory: $WORKDIR"
    exit -1
fi

cmd="${DIR}etching_conf_parse ${CONF} > ${WORKDIR}/${CONF}"
echo $cmd
eval $cmd

cmd="cd $WORKDIR"
echo $cmd
eval $cmd


#######################################################################################

#############################
#
# checking files
#
#echo "CHECKING FILES"

grep -v "#" $CONF | awk '{if($1=="sample") print $2}' > sample.list
grep -v "#" $CONF | awk '{if($1=="filter_fq") print $2}' > filter_fq.list
grep -v "#" $CONF | awk '{if($1=="filter_fa") print $2}' > filter_fa.list
FILTER=$(grep -v "#" $CONF | awk '{if($1=="filter_db") print $2}' | head)

if [ $(wc -l sample.list | awk '{print $1}') != 2 ]
then
    echo "ERROR!!! In config file"
    echo "Please use paired sample sequencing data."
    exit -1
fi

###########################
# sample files

for i in $(cat sample.list)
do
    if [ ! -f ${i} ]
    then
	echo "ERROR!!! In config file"
	echo "There is no input file: ${i}"
	exit -1
    fi
done


###########################
# filter_fq files

if [ $(wc -l filter_fq.list | awk '{print $1}') != 0 ]
then
    for i in $(cat filter_fq.list)
    do
	if [ ! -f ${i} ]
	then
	    echo "ERROR!!! In config file"
	    echo "There is no input file: ${i}"
	    #echo "--------------------------------------------"
	    #echo -e $USAGE
	    exit -1
	fi
    done
fi

###########################
# filter_fa files

if [ $(wc -l filter_fa.list | awk '{print $1}') != 0 ]
then
    for i in $(cat filter_fa.list)
    do
	if [ ! -f ${i} ]
	then
	    echo "ERROR!!! In config file"
	    echo "There is no input file: ${i}"
	    #echo "--------------------------------------------"
	    #echo -e $USAGE
	    exit -1
	fi
    done
fi

###########################
# filter_db files

if [ ${#FILTER} != 0 ]
then
    if [ ! -f ${FILTER}.kmc_pre ]
    then
	echo "ERROR!!! In config file"
	echo "There is no input file: ${FILTER}.kmc_pre"
	#echo "--------------------------------------------"
	#echo -e $USAGE
	exit -1
    fi
    if [ ! -f ${FILTER}.kmc_suf ]
    then
	echo "ERROR!!! In config file"
	echo "There is no input file: ${FILTER}.kmc_suf"
	#echo "--------------------------------------------"
	#echo -e $USAGE
	exit -1
    fi
fi

#############################
#
# CHECK PARAMETERS
#
if [ "$ORIENT" != "FR" ] && [ "$ORIENT" != "RF" ]
then
    echo "ERROR!!!"
    echo "-O must be FR or RF"
    exit -1
fi 


#############################
#
# CHECKING REFERENCE GENOME
#
GENOME=$(grep -v "#" ${CONF} | awk '{if($1=="genome") print $2}' )
if [ ! -f ${GENOME} ]
then
    echo "ERROR!!!"
    echo "There is no reference genome: $GENOME"
    exit -1
fi

CHECK1=$(grep -v "#" ${CONF} | awk '{if($1=="mapper") print $2}' | grep bwa)
CHECK2=$(grep -v "#" ${CONF} | awk '{if($1=="mapper") print $2}' )
if [ ${#CHECK1} != 0 ] || [ ${#CHECK2} == 0 ]
then
    for i in .amb .ann .bwt .pac .sa
    do
	if [ ! -f ${GENOME}${i} ]
	then
	    echo "ERROR!!!"
	    echo "${GENOME} was not indexed with bwa yet."
	    echo "Please index it."
	    exit -1
	fi
    done
fi

ANNOTATION=$(grep -v "#" ${CONF} | awk '{if($1=="annotation") print $2}' ) 
if [ ${#ANNOTATION} != 0 ]
then
    if [ ! -f ${ANNOTATION} ]
    then
	echo "ERROR!!!"
	echo "There is no annotation file: ${ANNOTATION}"
	exit -1
    fi
fi


#############################
#
# ETCHING FILTER
#

echo 
echo "[FILTER]"
DATE="[$(date)]";echo ${DATE}

if [ ${#KMERCUTOFF} != 0 ]
then
    KMERCITOFF="-c $KMERCUTOFF"
fi

mkdir logs

cmd="${DIR}etching_filter -i $CONF -t $THREADS $KMERCUTOFF -T ${DATATYPE} ${DIR_OPT} > logs/ETCHING_FILTER.log 2> logs/ETCHING_FILTER.err"
echo $cmd
eval $cmd

#############################
#
# CALLER
#

echo
echo "[CALLER]"
DATE="[$(date)]";echo ${DATE}

if [ $DATATYPE == "W" ]
then 
    cmd="${DIR}estimate_coverage sample $READLENGTH 31"
    echo $cmd
    DEPTH=$(eval $cmd 2> err)
    rm err
    DEPTH="-D $DEPTH"
else
    DEPTH=
fi

cmd="${DIR}etching_caller -b filtered_read.sort.bam -g $GENOME -o $PREFIX $DEPTH -P $PURITY -O $ORIENT $ALLSPLIT > logs/ETCHING_CALLER.log 2> logs/ETCHING_CALLER.err"
echo $cmd
eval $cmd


#############################
#
# SORTER
#
echo
echo "[SORTER]"
DATE="[$(date)]";echo ${DATE}

cmd="${DIR}etching_sorter -i ${PREFIX}.BND.vcf -o ${PREFIX}.BND -c $CUTOFF $ALGOR"
if [ ${#ML_PATH} != 0 ]
then
    cmd="${cmd} -m ${ML_PATH}"
fi
cmd="$cmd > logs/ETCHING_SORTER.BND.log 2> logs/ETCHING_SORTER.BND.err"
#cmd="${DIR}etching_sorter -i ${PREFIX}.BND.vcf -o ${PREFIX}.BND -c $CUTOFF $ALGOR > logs/ETCHING_SORTER.BND.log 2> logs/ETCHING_SORTER.BND.err"
echo $cmd
eval $cmd

cmd="${DIR}etching_sorter -i ${PREFIX}.SV.vcf -o ${PREFIX}.SV -c $CUTOFF $ALGOR"
if [ ${#ML_PATH} != 0 ]
then
    cmd="${cmd} -m ${ML_PATH}"
fi
cmd="$cmd > logs/ETCHING_SORTER.SV.log 2> logs/ETCHING_SORTER.SV.err"
#cmd="${DIR}etching_sorter -i ${PREFIX}.SV.vcf -o ${PREFIX}.SV -c $CUTOFF $ALGOR > logs/ETCHING_SORTER.SV.log 2> logs/ETCHING_SORTER.SV.err"
echo $cmd
eval $cmd


#############################
#
# FG_IDENTIFIER
#

if [ ${#ANNOTATION} != 0 ]
then
    echo
    echo "[FG_IDENTIFIER]"
    DATE="[$(date)]";echo ${DATE}
    
    cmd="${DIR}etching_fg_identifier ${PREFIX}.BND.etching_sorter.vcf $ANNOTATION > ${PREFIX}.BND.fusion_gene.txt"
    echo $cmd
    eval $cmd

    cmd="${DIR}etching_fg_identifier ${PREFIX}.SV.etching_sorter.vcf $ANNOTATION > ${PREFIX}.SV.fusion_gene.txt"
    echo $cmd
    eval $cmd
fi

cmd="cd -"
echo $cmd
eval $cmd

#############################
#
# COPY RESULTS
#

echo
echo "[RESULTS]"
#ln -s  ${WORKDIR}/${PREFIX}.BND.etching_sorter.vcf ${WORKDIR}/${PREFIX}.SV.etching_sorter.vcf ./
#cp  ${WORKDIR}/${PREFIX}.BND.etching_sorter.vcf ${WORKDIR}/${PREFIX}.SV.etching_sorter.vcf ./
#echo ${PREFIX}.BND.etching_sorter.vcf
#echo ${PREFIX}.SV.etching_sorter.vcf
cp ${WORKDIR}/${PREFIX}*etching_sorter.vcf ./
ls -1 ${PREFIX}*etching_sorter.vcf

if [ -f ${WORKDIR}/${PREFIX}.BND.fusion_gene.txt ]
then
    #ln -s ${WORKDIR}/${PREFIX}.BND.fusion_gene.txt 
    cp ${WORKDIR}/${PREFIX}.BND.fusion_gene.txt ./
    ls ${PREFIX}.BND.fusion_gene.txt
fi

if [ -f ${WORKDIR}/${PREFIX}.SV.fusion_gene.txt ]
then
    #ln -s ${WORKDIR}/${PREFIX}.SV.fusion_gene.txt 
    cp ${WORKDIR}/${PREFIX}.SV.fusion_gene.txt ./
    ls ${PREFIX}.SV.fusion_gene.txt
fi
echo
echo "[Finished]"
DATE="[$(date)]";echo ${DATE}
