use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_laccess.cgi' );
strict_ok( 'save_laccess.cgi' );
warnings_ok( 'save_laccess.cgi' );
