use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_lgzip.cgi' );
strict_ok( 'save_lgzip.cgi' );
warnings_ok( 'save_lgzip.cgi' );
