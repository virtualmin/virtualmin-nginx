use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_ldocs.cgi' );
strict_ok( 'save_ldocs.cgi' );
warnings_ok( 'save_ldocs.cgi' );
