use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_misc.cgi' );
strict_ok( 'edit_misc.cgi' );
warnings_ok( 'edit_misc.cgi' );
