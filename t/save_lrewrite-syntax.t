use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_lrewrite.cgi' );
strict_ok( 'save_lrewrite.cgi' );
warnings_ok( 'save_lrewrite.cgi' );
