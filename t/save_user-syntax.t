use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_user.cgi' );
strict_ok( 'save_user.cgi' );
warnings_ok( 'save_user.cgi' );
