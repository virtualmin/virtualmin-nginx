use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_lrewrite.cgi' );
strict_ok( 'edit_lrewrite.cgi' );
warnings_ok( 'edit_lrewrite.cgi' );
