use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    package MySimilarity;
    
    sub length_norm { 
        my ( $self, $num_tokens ) = @_;
        return $num_tokens == 0 ? 1 : log($num_tokens) + 1;
    }
    
    package MyFullTextType;
    use base qw( KinoSearch::FieldType::FullTextType );
    
    sub similarity { MySimilarity->new }
END_SYNOPSIS

my $constructor = qq|    my \$sim = KinoSearch::Search::Similarity->new;\n|;

{   "KinoSearch::Search::Similarity" => {
        bind_methods => [
            qw( IDF
                TF
                Encode_Norm
                Decode_Norm
                Query_Norm
                Length_Norm 
                Coord )
        ],
        make_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
            methods     => [qw( length_norm )],
        }
    }
}

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::Similarity     

SV*
get_norm_decoder(self)
    kino_Similarity *self;
CODE:
    RETVAL = newSVpvn( (char*)self->norm_decoder, (256 * sizeof(float)) );
OUTPUT: RETVAL

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.


