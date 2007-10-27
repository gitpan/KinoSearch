use strict;
use warnings;

package KinoSearch::Analysis::Tokenizer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );

our %instance_vars = (
    # inherited (and useless)
    language => '',

    # constructor params / members
    token_re => qr/\w+(?:'\w+)*/,
);

use KinoSearch::Analysis::Token;
use KinoSearch::Analysis::TokenBatch;

1;

__END__

__XS__

MODULE = KinoSearch  PACKAGE = KinoSearch::Analysis::Tokenizer

kino_TokenBatch*
_do_analyze(self_hv, batch_or_text_sv, ...)
    HV *self_hv;
    SV *batch_or_text_sv;
ALIAS:
    analyze_batch = 1
    analyze_text  = 2
    analyze_field = 3
CODE:
{
    kino_TokenBatch *batch           = NULL;
    SV              *token_re        = extract_sv(self_hv, SNL("token_re"));
    MAGIC           *mg              = NULL;
    REGEXP          *rx              = NULL;
    chy_u32_t        num_code_points = 0;
    SV              *wrapper         = sv_newmortal();
    char            *string          = NULL;
    STRLEN           string_len      = 0;
    RETVAL                           = kino_TokenBatch_new(NULL);
    
    if (ix == 1) {
        if (items != 2)
            CONFESS("usage: $batch = $analyzer->analyze_batch($batch)");
        EXTRACT_STRUCT( batch_or_text_sv, batch, kino_TokenBatch*,
            "KinoSearch::Analysis::TokenBatch");
    }
    else if (ix == 2) {
        if (items != 2)
            CONFESS("usage: $batch = $analyzer->analyze_text($text)");
        string = SvPVutf8( ST(1), string_len );
    }
    else if (ix == 3) {
        STRLEN   len;
        SV      *string_sv;
        char    *field_name;

        if (items != 3)
            CONFESS("analyze_field() takes 2 arguments, got %d", items - 1);
        if (!SvROK(batch_or_text_sv))
            CONFESS("first argument to analyze_field() must be hash ref");
            
        field_name  = SvPV(ST(2), len);
        string_sv   = extract_sv( (HV*)SvRV(batch_or_text_sv), 
                        field_name, len);
        string      = SvPVutf8(string_sv, string_len);
    }

    /* extract regexp struct from qr// entity */
    if (SvROK(token_re)) {
        SV *sv = SvRV(token_re);
        if (SvMAGICAL(sv))
            mg = mg_find(sv, PERL_MAGIC_qr); 
    }
    if (!mg)
        CONFESS("not a qr// entity");
    rx = (REGEXP*)mg->mg_obj;

    /* fake up an SV wrapper to feed to the regex engine */
    sv_upgrade(wrapper, SVt_PV);
    SvREADONLY_on(wrapper);
    SvLEN(wrapper) = 0;
    SvUTF8_on(wrapper);

    while (1) {
        char   *string_beg;
        char   *string_end;
        char   *string_arg;

        if (ix == 1) {
            kino_Token *token = Kino_TokenBatch_Next(batch);
            if (token == NULL)
                break;
            string_len   = token->len;
            string_beg   = token->text;
            string_end   = string_beg + string_len;
            string_arg   = string_beg;
        }
        else {
            string_beg   = string;
            string_end   = string_beg + string_len;
            string_arg   = string_beg;
        }

        /* wrap the string in an SV to please the regex engine */
        SvPVX(wrapper) = string_beg;
        SvCUR_set(wrapper, string_len);
        SvPOK_on(wrapper);

        while (
            pregexec(rx, string_arg, string_end, string_arg, 1, wrapper, 1)
        ) {
#if ((PERL_VERSION > 9) || (PERL_VERSION == 9 && PERL_SUBVERSION >= 5))
            char *const start_ptr = string_arg + rx->offs[0].start;
            char *const end_ptr   = string_arg + rx->offs[0].end;
#else 
            char *const start_ptr = string_arg + rx->startp[0];
            char *const end_ptr   = string_arg + rx->endp[0];
#endif
            chy_u32_t start, end;
            kino_Token *new_token;

            /* get start and end offsets in Unicode code points */
            for( ; string_arg < start_ptr; num_code_points++) {
                string_arg += KINO_STRHELP_UTF8_SKIP[(chy_u8_t)*string_arg];
                if (string_arg > string_end)
                    CONFESS("scanned past end of '%s'", string_beg);
            }
            start = num_code_points;
            for( ; string_arg < end_ptr; num_code_points++) {
                string_arg += KINO_STRHELP_UTF8_SKIP[(chy_u8_t)*string_arg];
                if (string_arg > string_end)
                    CONFESS("scanned past end of '%s'", string_beg);
            }
            end = num_code_points;

            /* add a token to the new_batch */
            new_token = kino_Token_new(
                start_ptr,
                (end_ptr - start_ptr),
                start,
                end,
                1.0f, /* boost always 1 for now */
                1     /* position increment */
            );
            Kino_TokenBatch_Append(RETVAL, new_token);
            REFCOUNT_DEC(new_token);
        }

        if (ix > 1) /* analyze_text and analyze_field only run one loop iter */
            break;
    }
}
OUTPUT: RETVAL
    

__POD__

=head1 NAME

KinoSearch::Analysis::Tokenizer - Customizable tokenizing.

=head1 SYNOPSIS

    my $whitespace_tokenizer
        = KinoSearch::Analysis::Tokenizer->new( token_re => qr/\S+/, );

    # or...
    my $word_char_tokenizer
        = KinoSearch::Analysis::Tokenizer->new( token_re => qr/\w+/, );

    # or...
    my $apostrophising_tokenizer = KinoSearch::Analysis::Tokenizer->new;

    # then... once you have a tokenizer, put it into a PolyAnalyzer
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [ $lc_normalizer, $word_char_tokenizer, $stemmer ], );


=head1 DESCRIPTION

Generically, "tokenizing" is a process of breaking up a string into an array
of "tokens".

    # before:
    my $string = "three blind mice";

    # after:
    @tokens = qw( three blind mice );

KinoSearch::Analysis::Tokenizer decides where it should break up the text
based on the value of C<token_re>.

    # before:
    my $string = "Eats, Shoots and Leaves.";

    # tokenized by $whitespace_tokenizer
    @tokens = qw( Eats, Shoots and Leaves. );

    # tokenized by $word_char_tokenizer
    @tokens = qw( Eats Shoots and Leaves   );

=head1 METHODS

=head2 new

    # match "it's" as well as "it" and "O'Henry's" as well as "Henry"
    my $token_re = qr/
            \w+       # Match word chars.
            (?:       # Group, but don't capture...
               '\w+   # ... an apostrophe plus word chars.
            )*        # Matching the apostrophe group is optional.
        /xsm;
    my $tokenizer = KinoSearch::Analysis::Tokenizer->new(
        token_re => $token_re, # default: what you see above
    );

Constructor.  Takes one hash style parameter.

=over

=item *

B<token_re> - must be a pre-compiled regular expression matching one token.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
