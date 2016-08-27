use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_net.cgi' );
strict_ok( 'save_net.cgi' );
warnings_ok( 'save_net.cgi' );
