use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'stop.cgi' );
strict_ok( 'stop.cgi' );
warnings_ok( 'stop.cgi' );
