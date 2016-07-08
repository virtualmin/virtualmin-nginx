use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'acl_security.pl' );
strict_ok( 'acl_security.pl' );
warnings_ok( 'acl_security.pl' );
