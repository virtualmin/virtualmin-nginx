use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_slogs.cgi' );
strict_ok( 'save_slogs.cgi' );
warnings_ok( 'save_slogs.cgi' );
