use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch     PACKAGE = KinoSearch::Store::FileDes

=for comment

For testing purposes only.  Track number of FileDes objects in existence.

=cut

chy_i32_t
object_count()
CODE:
    RETVAL = kino_FileDes_object_count;
OUTPUT: RETVAL

=for comment

For testing purposes only.  Used to help produce buffer alignment tests.

=cut

IV
_BUF_SIZE()
CODE:
   RETVAL = KINO_IO_STREAM_BUF_SIZE;
OUTPUT: RETVAL
END_XS_CODE

Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Store::FileDes",
    xs_code      => $xs_code,
    bind_methods => [qw( Length Close )],
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

