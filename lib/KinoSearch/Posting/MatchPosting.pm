use KinoSearch;

1;

__END__

__BINDING__

my $synopsis = <<'END_SYNOPSIS';
    # MatchPosting is used indirectly, by specifying in FieldType subclass.
    package MySchema::Category;
    use base qw( KinoSearch::FieldType::FullTextType );
    sub posting {
        my $self = shift;
        return KinoSearch::Posting::MatchPosting->new(@_);
    }
END_SYNOPSIS

Boilerplater::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KinoSearch::Posting::MatchPosting",
    bind_constructors => ["new"],
    bind_methods      => [qw( Get_Freq )],
#    make_pod => {
#        synopsis => $synopsis,
#    }
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

