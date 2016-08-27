use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_fcgi.cgi' );
strict_ok( 'save_fcgi.cgi' );
warnings_ok( 'save_fcgi.cgi' );
