use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_manual.cgi' );
strict_ok( 'edit_manual.cgi' );
warnings_ok( 'edit_manual.cgi' );
