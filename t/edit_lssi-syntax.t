use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_lssi.cgi' );
strict_ok( 'edit_lssi.cgi' );
warnings_ok( 'edit_lssi.cgi' );
