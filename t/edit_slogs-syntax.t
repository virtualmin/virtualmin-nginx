use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_slogs.cgi' );
strict_ok( 'edit_slogs.cgi' );
warnings_ok( 'edit_slogs.cgi' );
