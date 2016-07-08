use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_mime.cgi' );
strict_ok( 'save_mime.cgi' );
warnings_ok( 'save_mime.cgi' );
