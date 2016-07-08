use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_user.cgi' );
strict_ok( 'edit_user.cgi' );
warnings_ok( 'edit_user.cgi' );
