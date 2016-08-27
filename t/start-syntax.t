use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'start.cgi' );
strict_ok( 'start.cgi' );
warnings_ok( 'start.cgi' );
