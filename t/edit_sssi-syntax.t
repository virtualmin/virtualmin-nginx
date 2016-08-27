use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_sssi.cgi' );
strict_ok( 'edit_sssi.cgi' );
warnings_ok( 'edit_sssi.cgi' );
