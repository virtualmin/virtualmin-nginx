use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_manual.cgi' );
strict_ok( 'save_manual.cgi' );
warnings_ok( 'save_manual.cgi' );
