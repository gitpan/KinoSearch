package KinoSearch::Document::Doc;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars();

my %data;

sub set_value {
    $_[0]->{ $_[1] }->set_value( $_[2] );
}

sub get_value {
    return $_[0]->{ $_[1] }->get_value;
}

# TODO rework this interface before it goes live
sub set_boost {
    if ( @_ == 3 ) {
        $_[0]->{ $_[1] }->set_boost( $_[2] );
    }
    else {
        $data{ $_[0] }{boost} = $_[1];
    }
}

sub get_boost { $data{ $_[0] }{boost} }

# set the analyzer for a field
sub set_analyzer {
    $_[0]->{ $_[1] }->set_analyzer( $_[2] );
}

sub add_field {
    my ( $self, $field ) = @_;
    croak("argument to add_field must be a KinoSearch::Document::Field")
        unless $field->isa('KinoSearch::Document::Field');
    $self->{ $field->get_name } = $field;
}

# retrieve all fields
sub get_fields {
    values %{ $_[0] };
}

sub to_hashref {
    my $self = shift;
    my %hash;
    $hash{ $_->get_name } = $_->get_value for values %$self;
    return \%hash;
}

sub DESTROY {
    delete $data{ $_[0] };
}

1;

__END__

=head1 NAME

KinoSearch::Document::Doc - a document

=head1 SYNOPSIS

    my $doc = $invindexer->new_doc;
    $doc->set_value( 'title' => $title_text );
    $invindexer->add($doc);

=head1 DESCRIPTION

In KinoSearch, a Doc object is akin to a row in a database, in that it is made
up of several fields, each of which has a value.

Doc objects are only created via factory methods of other classes.  

=head1 METHODS

=head2 set_value get_value

    $doc->set_value( title => $title_text );
    my $text = $doc->get_value( 'title' );

C<set_value> and C<get_value> are used to modify and access the values of the
fields within a Doc object.

=head2 to_hashref

    my $hashref = $doc->to_hashref;

Return the doc as a hashref, with the field names as hash keys and the field
values as values.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_04.

=cut
