use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_location.cgi' );
strict_ok( 'edit_location.cgi' );
warnings_ok( 'edit_location.cgi' );
