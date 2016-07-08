use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_location.cgi' );
strict_ok( 'save_location.cgi' );
warnings_ok( 'save_location.cgi' );
