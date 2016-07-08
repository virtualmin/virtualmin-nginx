use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_net.cgi' );
strict_ok( 'edit_net.cgi' );
warnings_ok( 'edit_net.cgi' );
