#!/bin/bash
set -e

# Comment to use KenLM, otherwise specify path to SRILM
srilm_dir=/path/to/srilm/bin/i686-m64

# Specify path to NUCLE target file
nucle_file=/path/to/nucle.cor

# Modify to skip steps smaller than this value
step=0

mkdir -p logs

if [ $step -le 0 ] ; then
    cd software; ./download.sh; cd ..
fi

moses_dir=$PWD/software/mosesdecoder
moses_bin_dir=$moses_dir/tools

source software/env/bin/activate

if [ $step -le 1 ] ; then
    echo "(1) Preparing dataset"
    # Download spell-check corpus
    mkdir -p data
    cd data; ./download.sh; cd ..
    conll13_file=data/release2.3.1/revised/data/official-preprocessed.m2
    conll14_file=data/conll14st-test-data/noalt/official-2014.0.m2
    # Prepare data splits
    mkdir -p model
    # Get unique words from NUCLE
    python get_nucle_words.py < $nucle_file > data/nucle.txt
    # Convert to Moses parallel format and make train, dev, test split 
    # Use Holbrook for dev and Mec errors from CoNLL'13-14 for test
    cat data/{aspell,missp,wikipedia}.dat | python prepare_data.py data/train.spell
    cat data/train.spell.err data/nucle.txt > data/train.err
    cat data/train.spell.cor data/nucle.txt > data/train.cor
    cat data/holbrook-missp.dat | python prepare_data.py data/dev
    cat $conll13_file $conll14_file | python create_conll_test.py data/test-conll
    # Clean to make sure Giza++ doesn't throw errors
    perl $moses_dir/scripts/training/clean-corpus-n.perl data/train cor err data/train.clean 1 80
    # Convert from parallel to m2 format (for tuning and evaluation)
    python software/errant/parallel_to_m2.py -orig data/dev.err -cor data/dev.cor -out data/dev.m2 -lev -merge all-split
    python software/errant/parallel_to_m2.py -orig data/test-conll.err -cor data/test-conll.cor -out data/test-conll.m2 -lev -merge all-split
fi

if [ $step -le 2 ] ; then
    echo "(2) Training Language Model"
    # Language Model Training
    if [[ $srilm_dir ]] ; then
        $srilm_dir/ngram-count -order 5 -interpolate -kndiscount -addsmooth1 0.0 -unk -text data/train.cor -lm model/lm.char.arpa > logs/lm.log 2>&1
        gzip -c model/lm.char.arpa > model/lm.char.arpa.gz
    else
        $moses_dir/bin/lmplz -S 10G -o 5 --text data/train.cor 2> logs/lm.log | gzip > model/lm.char.arpa.gz
    fi
    $moses_dir/bin/build_binary model/lm.char.arpa.gz model/lm.char.kenlm >> logs/lm.log 2>&1
fi

if [ $step -le 3 ] ; then
    echo "(3) Training Translation Model"
    # Translation Model Training
    rm -rf work_dir; mkdir -p work_dir
    perl $moses_dir/scripts/training/train-model.perl \
        --root-dir $PWD/work_dir \
        --model-dir $PWD/model \
        --corpus $PWD/data/train.clean \
        --f err --e cor \
        --lm 0:5:$PWD/model/lm.char.kenlm:8 \
        --external-bin-dir $moses_bin_dir \
        --alignment=grow-diag-final \
        --mgiza \
        --mgiza-cpus 8 \
        --cores 16 \
        --sort-buffer-size=5G \
        --sort-parallel=16 \
        --temp-dir work_dir \
        --parallel \
        --sort-compress gzip > logs/giza.log 2>&1
    # Adjust generated moses.ini file to include EditOps and disable distortion
    perl adjust_moses_ini.perl model/moses.ini model/moses.adjusted.ini
fi

if [ $step -le 4 ] ; then
    echo "(4) Tuning"
    # Tuning based on M2
    rm -rf work_dir/tuning
    scorer="M2SCORER"
    config="ignore_whitespace_casing:true"

    perl $moses_dir/scripts/training/mert-moses.pl \
        $PWD/data/dev.err $PWD/data/dev.m2 \
        $moses_dir/bin/moses $PWD/model/moses.adjusted.ini \
        --working-dir=$PWD/work_dir/tuning \
        --mertdir=$moses_dir/bin \
        --mertargs "--sctype $scorer --scconfig $config" \
        --no-filter-phrase-table \
        --nbest=100 \
        --threads 16 --decoder-flags "-threads 16" > logs/mert.log 2>&1
fi

if [ $step -le 5 ] ; then
    echo "(5) Evaluating"
    for testset in "test-conll" "dev"; do
        cat data/$testset.err |\
        $moses_dir/bin/moses -f work_dir/tuning/moses.ini > data/$testset.trans.cor
        software/m2scorer/m2scorer --beta 0.5 --max_unchanged_words 2 data/$testset.trans.cor data/$testset.m2 | tee logs/$testset.m2.log
    done
fi
