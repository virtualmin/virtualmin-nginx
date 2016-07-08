use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_sproxy.cgi' );
strict_ok( 'edit_sproxy.cgi' );
warnings_ok( 'edit_sproxy.cgi' );
