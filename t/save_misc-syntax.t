use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_misc.cgi' );
strict_ok( 'save_misc.cgi' );
warnings_ok( 'save_misc.cgi' );
