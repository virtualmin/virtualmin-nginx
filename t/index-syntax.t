use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'index.cgi' );
strict_ok( 'index.cgi' );
warnings_ok( 'index.cgi' );
