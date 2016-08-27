use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_mime.cgi' );
strict_ok( 'edit_mime.cgi' );
warnings_ok( 'edit_mime.cgi' );
