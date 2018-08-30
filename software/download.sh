#!/bin/bash
curdir=$PWD
if [ ! -d errant ] ; then
    git clone https://github.com/chrisjbryant/errant
    rm -rf env; virtualenv -p python3 env
    source env/bin/activate
    pip3 install -U spacy==1.9.0
    python3 -m spacy download en
    pip3 install -U nltk
fi
if [ ! -d mosesdecoder ] ; then
    git clone https://github.com/snukky/mosesdecoder
    cd mosesdecoder
    git checkout gleu
    make -f contrib/Makefiles/install-dependencies.gmake
    ./compile.sh
    cd $curdir
fi
if [ ! -d mgiza ] ; then
    git clone https://github.com/moses-smt/mgiza.git
    cd mgiza/mgizapp
    cmake .
    make
    make install

    BINDIR=$curdir/mosesdecoder/tools
    mkdir -p $BINDIR
    cp bin/* $BINDIR
    cp scripts/merge_alignment.py $BINDIR
    cd $curdir
fi
[ -d m2scorer ] || git clone https://github.com/nusnlp/m2scorer
