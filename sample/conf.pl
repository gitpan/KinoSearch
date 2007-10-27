# conf.pl -- Configuration file shared by invindexer.pl and search.cgi.
#
# (The default values are set up so that "perl -Mblib sample/invindexer.pl"
# will work after "./Build code" and should be changed as needed.)
{
    # Arrayref of library paths to add to @INC.
    lib => ['sample'],

    # Path to the invindex on the file system.
    path_to_invindex => 'uscon_invindex',

    # File system path to the directory which holds the US Constitution html
    # files.
    uscon_source => 'sample/us_constitution',
};