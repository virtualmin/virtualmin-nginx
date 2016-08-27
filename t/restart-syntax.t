use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'restart.cgi' );
strict_ok( 'restart.cgi' );
warnings_ok( 'restart.cgi' );
