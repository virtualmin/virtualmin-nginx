use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_server.cgi' );
strict_ok( 'save_server.cgi' );
warnings_ok( 'save_server.cgi' );
