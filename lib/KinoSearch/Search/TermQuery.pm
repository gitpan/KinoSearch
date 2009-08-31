use KinoSearch;

1;

__END__

__BINDING__

my $term_query_xs_code = <<'END_XS_CODE';
MODULE = KinoSearch   PACKAGE = KinoSearch::Search::TermQuery

SV*
get_term(self)
    kino_TermQuery *self;
CODE:
{
    kino_Obj *term = Kino_TermQuery_Get_Term(self);
    if (KINO_OBJ_IS_A(term, KINO_CHARBUF)) {
         RETVAL = XSBind_cb_to_sv((kino_CharBuf*)term);
    }
    else {
        RETVAL = Kino_Obj_To_Host(term);
    }
}
OUTPUT: RETVAL
END_XS_CODE

my $synopsis = <<'END_SYNOPSIS';
    my $term_query = KinoSearch::Search::TermQuery->new(
        field => 'content',
        term  => 'foo', 
    );
    my $hits = $searcher->hits( query => $term_query );
END_SYNOPSIS

my $constructor = <<'END_CONSTRUCTOR';
    my $term_query = KinoSearch::Search::TermQuery->new(
        field => 'content',    # required
        term  => 'foo',        # required
    );
END_CONSTRUCTOR

Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Search::TermQuery",
    xs_code           => $term_query_xs_code,
    bind_methods      => [qw( Get_Field )],
    bind_constructors => ["new"],
    make_pod          => {
        synopsis    => $synopsis,
        constructor => { sample => $constructor },
    },
);
Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Search::TermCompiler",
    bind_constructors => ["do_new"],
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

