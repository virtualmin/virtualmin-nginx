use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'list_users.cgi' );
strict_ok( 'list_users.cgi' );
warnings_ok( 'list_users.cgi' );
