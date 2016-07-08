use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_lfcgi.cgi' );
strict_ok( 'edit_lfcgi.cgi' );
warnings_ok( 'edit_lfcgi.cgi' );
