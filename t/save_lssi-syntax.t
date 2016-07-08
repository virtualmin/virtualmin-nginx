use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_lssi.cgi' );
strict_ok( 'save_lssi.cgi' );
warnings_ok( 'save_lssi.cgi' );
