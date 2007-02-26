use strict;
use warnings;

package KinoSearch::Analysis::TokenBatch;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN { __PACKAGE__->init_instance_vars( text => undef ) }
our %instance_vars;

use KinoSearch::Analysis::Token;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Analysis::TokenBatch

kino_TokenBatch*
new(...)
CODE:
{
    kino_Token *starter_token = NULL;
    /* parse params, only if there's more than one arg */
    if (items > 1) {
        HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
            "KinoSearch::Analysis::TokenBatch::instance_vars");
        SV *text_sv = extract_sv(args_hash, SNL("text"));
        STRLEN len;
        char *text = SvPVutf8(text_sv, len);
        starter_token = kino_Token_new(text, len, 0, len, 1.0, 1);
    }
        
    RETVAL = kino_TokenBatch_new(starter_token);
    REFCOUNT_DEC(starter_token);
}
OUTPUT: RETVAL

void
append(self, token)
    kino_TokenBatch *self;
    kino_Token* token;
PPCODE:
    Kino_TokenBatch_Append(self, token);

=for comment

Add many tokens to the batch, by supplying the string to be tokenized, and
arrays of token starts and token ends.

=cut

void
add_many_tokens(self, string_sv, starts_av, ends_av, ...)
    kino_TokenBatch *self;
    SV              *string_sv;
    AV              *starts_av;
    AV              *ends_av;
PPCODE:
{
    const kino_u32_t num_starts = av_len(starts_av) + 1;
    size_t len;
    char *string_top            = SvPV(string_sv, len);
    char *ptr                   = string_top;
    char *token_start           = string_top;
    char *limit                 = SvEND(string_sv);
    size_t num_code_points      = 0;
    size_t i;
    AV   *boosts_av             = NULL;

    if( !SvUTF8(string_sv) )
        CONFESS("source string not encoded as UTF-8");

    if (items == 5) {
        if (SvROK(ST(4)) && SvTYPE(SvRV(ST(4)))==SVt_PVAV)
            boosts_av = (AV*)SvRV(ST(4));
        else    
            CONFESS("boosts_av is not an array reference");
    }

    for (i = 0; i < num_starts; i++) {
        size_t start_offset, end_offset;
        kino_Token *token;
        float boost = 1.0;

        /* retrieve start and end */
        SV **const start_sv_ptr = av_fetch(starts_av, i, 0);
        SV **const end_sv_ptr   = av_fetch(ends_av, i, 0);
        if (start_sv_ptr == NULL)
            CONFESS("Failed to retrieve @starts array element");
        if (end_sv_ptr == NULL)
            CONFESS("Failed to retrieve @ends array element");
        start_offset = SvUV(*start_sv_ptr);
        end_offset   = SvUV(*end_sv_ptr);

        /* retrieve boost, if supplied */
        if (boosts_av != NULL) {
            SV **const boost_sv_ptr = av_fetch(boosts_av, i, 0);
            if (boost_sv_ptr == NULL)
                CONFESS("Failed to retrieve @boosts array element");
            boost = SvNV(*boost_sv_ptr);
        }

        /* scan to, or continue scanning to, the start and end offsets */
        for ( ; num_code_points < start_offset; num_code_points++) {
            ptr += KINO_STRHELP_UTF8_SKIP[(kino_u8_t)*ptr];
            if (ptr > limit)
                CONFESS("scanned past end of '%s'", string_top);
        }
        token_start = ptr;
        for ( ; num_code_points < end_offset; num_code_points++) {
            ptr += KINO_STRHELP_UTF8_SKIP[(kino_u8_t)*ptr];
            if (ptr > limit)
                CONFESS("scanned past end of '%s'", string_top);
        }

        /* calculate the start of the substring and add the token */
        token = kino_Token_new(
            token_start,
            (ptr - token_start),
            start_offset,
            end_offset,
            boost,
            1
        );
        Kino_TokenBatch_Append(self, token);
        REFCOUNT_DEC(token);
    }
}

=for comment

Take an array of Perl scalars and map their string contents to the texts for
each token in the batch.

=cut 

void
set_all_texts(self, texts_av)
    kino_TokenBatch *self;
    AV              *texts_av;
PPCODE:
{
    kino_i32_t i;
    const kino_i32_t max = av_len(texts_av);

    for (i = 0; i <= max; i++) {
        kino_Token *const token = (kino_Token*)Kino_TokenBatch_Fetch(self, i);
        SV **const sv_ptr = av_fetch(texts_av, i, 0);
        char *text;
        size_t len;

        if (sv_ptr == NULL)
            CONFESS("Encountered a null SV* pointer");
        text = SvPVutf8(*sv_ptr, len);

        if (token == NULL) {
            CONFESS("Batch size %d doesn't match array size %d",
                self->size, (max + 1));
        }
        free(token->text);
        token->text = kino_StrHelp_strndup(text, len);
        token->len = len;
    }
}

=for comment

Return a Perl array whose elements correspond to the token texts in this
batch.

=cut

void
get_all_texts(self)
    kino_TokenBatch *self;
PPCODE:
{
    AV *const out_av = newAV();
    kino_u32_t i;

    for (i = 0; i < self->size; i++) {
        kino_Token *const token = (kino_Token*)Kino_TokenBatch_Fetch(self, i);
        SV *const text = newSVpvn(token->text, token->len);
        SvUTF8_on(text);
        av_push(out_av, text);
    }

    XPUSHs(sv_2mortal( newRV_noinc((SV*)out_av) ));
    XSRETURN(1);
}


void
_set_or_get(self, ...) 
    kino_TokenBatch *self;
ALIAS:
    get_size         = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = newSVuv(self->size);
             break;
    
    END_SET_OR_GET_SWITCH
}

void
reset(self)
    kino_TokenBatch *self;
PPCODE:
    Kino_TokenBatch_Reset(self);

void
invert(self)
    kino_TokenBatch *self;
PPCODE:
    Kino_TokenBatch_Invert(self);

SV*
next(self)
    kino_TokenBatch *self;
CODE:
{
    kino_Token *token = Kino_TokenBatch_Next(self);
    RETVAL = token == NULL
        ? newSV(0)
        : kobj_to_pobj(token);
}
OUTPUT: RETVAL

__POD__

=head1 NAME

KinoSearch::Analysis::TokenBatch - A collection of tokens.

=head1 SYNOPSIS

    # create a TokenBatch with a single Token
    my $source_batch = KinoSearch::Analysis::TokenBatch->new(
        text => 'Key Lime Pie',
    );

    # lowercase and split text into multiple tokens, append to new batch
    my $dest_batch = KinoSearch::Analysis::TokenBatch->new;
    while ( my $source_token = $source_batch->next ) {
        my $source_text = $source_token->get_text;
        while ( $source_text =~ /\s*?(\S+)/g ) {
            my $new_token = KinoSearch::Analysis::Token->new(
                text         => lc($1),
                start_offset => $-[1],
                end_offset   => $+[1],
            );
            $dest_batch->append($new_token);
        }
    }

    # prints 'keylimepie'
    while ( my $token = $dest_batch->next ) { 
        print $token->get_text;
    }


=head1 DESCRIPTION

A TokenBatch is a collection of L<Tokens|KinoSearch::Analysis::Token> objects
which you can add to, then iterate over.  

=head1 METHODS

=head2 new

    my $batch = KinoSearch::Analysis::TokenBatch->new(
        text => $utf8_text,
    );

    # ... which is equivalent to:
    my $batch = KinoSearch::Analysis::TokenBatch->new;
    my $token = KinoSearch::Analysis::Token->new(
        text         => $utf8_text,
        start_offset => 0,
        end_offset   => length($utf8_text),
    );
    $batch->append($token);

Constructor.  Takes one optional hash-style argument.

=over

=item *

B<text> - UTF-8 encoded text, used to prime the TokenBatch with a single
initial <Token|KinoSearch::Analysis::Token>.

=back

=head2 append 

    $batch->append($token);

Tack a Token onto the end of the batch.

=head2 add_many_tokens

    $batch->add_many_tokens( $string, \@starts, \@ends );
    # or...
    $batch->add_many_tokens( $string, \@starts, \@ends, \@boosts );

High efficiency method for adding multiple tokens to the batch with one call.
The starts and ends, which must be specified in characters (not bytes), will
be used to identify substrings of C<$string> to use as token texts.

(Note: boosts should be supplied only for fields which are set to
C<store_pos_boost>.)

=head2 next

    while ( my $token = $batch->next ) {
        # ...
    }

Return the next token in the TokenBatch, or undef if out of tokens.

=head2 reset

    $batch->reset;

Reset the TokenBatch's iterator, so that the next call to next() returns the
first Token in the batch.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=cut

