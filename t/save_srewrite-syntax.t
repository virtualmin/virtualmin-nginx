use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_srewrite.cgi' );
strict_ok( 'save_srewrite.cgi' );
warnings_ok( 'save_srewrite.cgi' );
