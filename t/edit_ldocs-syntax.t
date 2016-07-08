use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_ldocs.cgi' );
strict_ok( 'edit_ldocs.cgi' );
warnings_ok( 'edit_ldocs.cgi' );
