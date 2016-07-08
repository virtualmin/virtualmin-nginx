use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_lgzip.cgi' );
strict_ok( 'edit_lgzip.cgi' );
warnings_ok( 'edit_lgzip.cgi' );
