use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'virtual_feature.pl' );
strict_ok( 'virtual_feature.pl' );
warnings_ok( 'virtual_feature.pl' );
