use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_srewrite.cgi' );
strict_ok( 'edit_srewrite.cgi' );
warnings_ok( 'edit_srewrite.cgi' );
