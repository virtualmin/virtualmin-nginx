use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_server.cgi' );
strict_ok( 'edit_server.cgi' );
warnings_ok( 'edit_server.cgi' );
