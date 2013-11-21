use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings;
use Test::Fatal;
binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

subtest "default exports" => sub {

    package WantDefaultExports;
    use Try::Tiny::Retry;
    for my $f (qw/retry retry_if try catch finally/) {
        Test::More::can_ok( __PACKAGE__, $f );
    }
};

subtest "all exports" => sub {

    package WantAllExports;
    use Try::Tiny::Retry ':all';
    for my $f (qw/retry retry_if delay delay_exp try catch finally/) {
        Test::More::can_ok( __PACKAGE__, $f );
    }
};

done_testing;
# COPYRIGHT

# vim: ts=4 sts=4 sw=4 et:
