use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis    = <<'END_SYNOPSIS';
    my $bit_vec = KinoSearch::Util::BitVector->new( capacity => 8 );
    my $other   = KinoSearch::Util::BitVector->new( capacity => 8 );
    $bit_vec->set($_) for ( 0, 2, 4, 6 );
    $other->set($_)   for ( 1, 3, 5, 7 );
    $bit_vec->or($other);
    print "$_\n" for @{ $bit_vec->to_array };    # prints 0 through 7.
END_SYNOPSIS
my $constructor = <<'END_CONSTRUCTOR';
    my $bit_vec = KinoSearch::Util::BitVector->new( 
        capacity => $doc_max + 1,   # default 0,
    );
END_CONSTRUCTOR

{   "KinoSearch::Util::BitVector" => {
        bind_methods => [
            qw( Get 
                Set 
                Clear 
                Clear_All 
                And 
                Or
                And_Not 
                Xor 
                Flip 
                Flip_Block 
                Next_Set_Bit
                To_Array
                Grow 
                Count 
                Copy )
        ],
        make_getters      => [qw( cap )],
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
            methods     => [
                qw( get 
                    set 
                    clear 
                    clear_all 
                    and 
                    or
                    and_not 
                    xor 
                    flip 
                    flip_block 
                    next_set_bit 
                    to_array 
                    grow 
                    count 
                    copy )
            ],
        }
    },
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

