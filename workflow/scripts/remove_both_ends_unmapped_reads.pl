use strict;

while(<STDIN>){
    if (/^\@/) { # header line
        print $_;
        next;
    }

    chomp;

    my @F = split /\t/, $_, -1;

    # don't output if both ends are unmapped. It may be better to check the FLAG field, but let's do the simple way first
    print "$_\n" unless ($F[2] eq "*" && $F[6] eq "*");

}
