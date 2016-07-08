use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_laccess.cgi' );
strict_ok( 'edit_laccess.cgi' );
warnings_ok( 'edit_laccess.cgi' );
