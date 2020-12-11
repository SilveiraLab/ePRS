#!/bin/sh
set -e

### MEANEY LAB ###

GEN_FILE=$1
SAMPLE_FILE=$2
OUTPUT=$3


# Copy INPUT in OUTPUT dir (the script writting in the INPUT directory)
mkdir -p $OUTPUT
DIR_TO_CP_INPUTS=$OUTPUT/derivated_input_data
mkdir           $DIR_TO_CP_INPUTS
ln -s $PWD/$GEN_FILE    $DIR_TO_CP_INPUTS/
ln -s $PWD/$SAMPLE_FILE $DIR_TO_CP_INPUTS/

GEN_FILE_BASENAME=`basename $GEN_FILE`
echo "GEN_FILE_BASENAME"
echo $GEN_FILE_BASENAME
GEN_FILE_BASENAME_WITHOUT_EXT="${GEN_FILE_BASENAME%.*}"
echo "GEN_FILE_BASENAME_WITHOUT_EXT"
echo $GEN_FILE_BASENAME_WITHOUT_EXT
GEN_FILE_WITHOUT_EXT=$DIR_TO_CP_INPUTS/$GEN_FILE_BASENAME_WITHOUT_EXT
echo "GEN_FILE_WITHOUT_EXT"
echo $GEN_FILE_WITHOUT_EXT


GWAS="/ePRS/fix_data/gwas_nodup_noambig.txt"
PRSOS="/PRSoS/PRSoS.py"

### RUN ###

echo subset geno + GWAS

awk 'NR==FNR{a[$1];next}$2 in a{print}' $GWAS $GEN_FILE              > $OUTPUT/score.gentemp
head -1 $GWAS                                                        > $OUTPUT/score_gwastemp.txt
awk 'NR==FNR{a[$2];next}$1 in a{print}' $OUTPUT/score.gentemp $GWAS >> $OUTPUT/score_gwastemp.txt
cut -f1-8 -d' ' $OUTPUT/score.gentemp                                > $OUTPUT/score.gentempnosam

echo output clumpit file
cut -f1-2 $OUTPUT/score_gwastemp.txt                                >> $OUTPUT/score_clumpit.txt

if [ -e $GEN_FILE.fam ]; then
  echo "bfile exists"
else
  echo "using plink to convert gen to bfile"
  plink --gen $GEN_FILE \
        --sample $SAMPLE_FILE \
        --keep-allele-order \
        --make-bed \
        --out $GEN_FILE_WITHOUT_EXT
fi

echo "Clumping"

plink --bfile $GEN_FILE_WITHOUT_EXT \
      --clump $OUTPUT/score_clumpit.txt \
      --clump-p1 1 --clump-p2 1 --clump-kb 500 --clump-r2 0.2 \
      --out $OUTPUT/score_clumpit

awk 'NR==FNR{a[$3];next}$2 in a{print}' $OUTPUT/score_clumpit.clumped $OUTPUT/score.gentemp              > $OUTPUT/score_clumped1.gen
awk 'NR==FNR{a[$2];next}$1 in a{print}' $OUTPUT/score_clumped1.gen $OUTPUT/score_gwastemp.txt           >> $OUTPUT/score_clumped1.txt
cat /ePRS/fix_data/header.txt                                                                            > $OUTPUT/score_clumped.txt
awk '{$7=$6"-"$1} 1' $OUTPUT/score_clumped1.txt | awk 'BEGIN {FS=" ";OFS="\t"} {$1=$1}1'                >> $OUTPUT/score_clumped.txt
awk 'NR==FNR{a[$1]=$7; next} $2 in a{$2=a[$2]}1' $OUTPUT/score_clumped.txt $OUTPUT/score_clumped1.gen    > $OUTPUT/score_clumped2.gen
cat /ePRS/fix_data/header2.txt                                                                           > $OUTPUT/score_clumped2.txt
awk 'NR>1{print $7, $2, $3, $4, $5}' $OUTPUT/score_clumped.txt | awk 'BEGIN {FS=" ";OFS="\t"} {$1=$1}1' >> $OUTPUT/score_clumped2.txt

echo "ePRS calculation"
# add parameters accordingly::
spark-submit --master local[12] $PRSOS $OUTPUT/score_clumped2.gen $OUTPUT/score_clumped2.txt $OUTPUT/score_prs \
             --sample $SAMPLE_FILE \
             --snp_log \
             --filetype GEN \
             --no_a1f \
             --thresholds 1 \
             --check_dup


rm -rf $DIR_TO_CP_INPUTS/$GEN_FILE 
rm -rf $DIR_TO_CP_INPUTS/$SAMPLE_FILE
cd $OUTPUT
ls | grep clump | xargs rm
ls | grep temp | xargs rm
