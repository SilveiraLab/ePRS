#!/bin/sh
set -e

### MEANEY LAB ###

mkdir ePRS_score

GENO_data_file=$1

#NEED TO ENTER::

GWAS="/ePRS/fix_data/gwas_nodup_noambig.txt"
PRSOS="/PRSoS/PRSoS.py"

echo subset geno + GWAS

awk 'NR==FNR{a[$1];next}$2 in a{print}' $GWAS $GENO_data_file.gen       > ePRS_score/score.gentemp
head -1 $GWAS                                                           > ePRS_score/score_gwastemp.txt
awk 'NR==FNR{a[$2];next}$1 in a{print}' ePRS_score/score.gentemp $GWAS >> ePRS_score/score_gwastemp.txt
cut -f1-8 -d' ' ePRS_score/score.gentemp                                > ePRS_score/score.gentempnosam

echo output clumpit file
cut -f1-2 ePRS_score/score_gwastemp.txt                                >> ePRS_score/score_clumpit.txt

if [ -e $GENO_data_file.fam ]; then
  echo "bfile exists"
else
  echo "using plink to convert gen to bfile"
  plink --gen $GENO_data_file.gen \
        --sample $GENO_data_file.sample \
        --keep-allele-order \
        --make-bed \
        --out $GENO_data_file
fi

echo "Clumping"

plink --bfile $GENO_data_file \
      --clump ePRS_score/score_clumpit.txt \
      --clump-p1 1 --clump-p2 1 --clump-kb 500 --clump-r2 0.2 \
      --out ePRS_score/score_clumpit

awk 'NR==FNR{a[$3];next}$2 in a{print}' ePRS_score/score_clumpit.clumped ePRS_score/score.gentemp           > ePRS_score/score_clumped1.gen
awk 'NR==FNR{a[$2];next}$1 in a{print}' ePRS_score/score_clumped1.gen ePRS_score/score_gwastemp.txt        >> ePRS_score/score_clumped1.txt
cat /ePRS/fix_data/header.txt                                                                               > ePRS_score/score_clumped.txt
awk '{$7=$6"-"$1} 1' ePRS_score/score_clumped1.txt | awk 'BEGIN {FS=" ";OFS="\t"} {$1=$1}1'                >> ePRS_score/score_clumped.txt
awk 'NR==FNR{a[$1]=$7; next} $2 in a{$2=a[$2]}1' ePRS_score/score_clumped.txt ePRS_score/score_clumped1.gen > ePRS_score/score_clumped2.gen
cat /ePRS/fix_data/header2.txt                                                                              > ePRS_score/score_clumped2.txt
awk 'NR>1{print $7, $2, $3, $4, $5}' ePRS_score/score_clumped.txt | awk 'BEGIN {FS=" ";OFS="\t"} {$1=$1}1' >> ePRS_score/score_clumped2.txt

echo "ePRS calculation"
# add parameters accordingly::
spark-submit --master local[12] $PRSOS ePRS_score/score_clumped2.gen ePRS_score/score_clumped2.txt ePRS_score/score_prs \
             --sample $GENO_data_file.sample \
             --snp_log \
             --filetype GEN \
             --no_a1f \
             --thresholds 1 \
             --check_dup

cd ePRS_score
ls | grep clump | xargs rm
ls | grep temp | xargs rm
