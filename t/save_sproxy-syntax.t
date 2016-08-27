use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_sproxy.cgi' );
strict_ok( 'save_sproxy.cgi' );
warnings_ok( 'save_sproxy.cgi' );
