use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_sssi.cgi' );
strict_ok( 'save_sssi.cgi' );
warnings_ok( 'save_sssi.cgi' );
