use KinoSearch;

1;

__END__

__AUTO_XS__

my $synopsis = <<'END_SYNOPSIS';
    # ScorePosting is used indirectly, by specifying in FieldType subclass.
    package MySchema::Category;
    use base qw( KinoSearch::FieldType::FullTextType );
    # (It's the default, so you don't need to spec it.)
    # sub posting {
    #     my $self = shift;
    #     return KinoSearch::Posting::ScorePosting->new(@_);
    # }
END_SYNOPSIS

{   "KinoSearch::Posting::ScorePosting" => {
        make_constructors  => ["new"],
        make_getters       => [qw( weight )],
#        make_pod => {
#            synopsis => $synopsis,
#        }
    }
}

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Posting::ScorePosting

SV*
get_prox(self)
    kino_ScorePosting *self;
CODE:
{
    AV *out_av            = newAV();
    chy_u32_t *positions  = self->prox;
    chy_u32_t i;

    for (i = 0; i < self->freq; i++) {
        SV *pos_sv = newSVuv(positions[i]);
        av_push(out_av, pos_sv);
    }

    RETVAL = newRV_noinc((SV*)out_av);
}
OUTPUT: RETVAL

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

