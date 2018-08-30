#!/usr/bin/perl

use strict;

###############################################################################
# Adjust moses.ini to work with files in $BINMODEL_DIR

my ($input_ini, $output_ini) = @ARGV;
print("Adjusting $input_ini\n");
open( INI1, "<", "$input_ini" )    or die "Cannot open $input_ini for reading\n";
open( INI2, ">", "$output_ini" ) or die "Cannot open $output_ini for writing\n";

while (<INI1>) {
    if (/\[distortion-limit\]/) {
        print INI2 "[distortion-limit]\n";
        print INI2 "1\n";
        my $skip = <INI1>;
        next;
    }

    if (/\[feature\]/) {
        print INI2 "[feature]\n";
        print INI2 "EditOps scores=dis\n";
        next;
    }

    if (/\[weight\]/) {
        print INI2 "[weight]\n";
        print INI2 "EditOps0= 0.2 0.2 0.2\n";
        next;
    }

    if (/Distortion/) {
        next;
    }

    print INI2 $_;
}

print INI2 "\n";
print INI2 "[search-algorithm]\n";
print INI2 "1\n";

close(INI2);
close(INI1);
print("Finished adjusting $input_ini\n");
