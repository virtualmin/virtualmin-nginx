use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_saccess.cgi' );
strict_ok( 'save_saccess.cgi' );
warnings_ok( 'save_saccess.cgi' );
