use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_lproxy.cgi' );
strict_ok( 'edit_lproxy.cgi' );
warnings_ok( 'edit_lproxy.cgi' );
