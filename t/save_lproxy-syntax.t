use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_lproxy.cgi' );
strict_ok( 'save_lproxy.cgi' );
warnings_ok( 'save_lproxy.cgi' );
