use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_lfcgi.cgi' );
strict_ok( 'save_lfcgi.cgi' );
warnings_ok( 'save_lfcgi.cgi' );
