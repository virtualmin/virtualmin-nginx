use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_fcgi.cgi' );
strict_ok( 'edit_fcgi.cgi' );
warnings_ok( 'edit_fcgi.cgi' );
