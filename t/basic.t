use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings;
use Test::Fatal;
binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

use Try::Tiny;
use Try::Tiny::Retry qw/:all/;

subtest 'default retry and fail' => sub {
    my $count  = 0;
    my $caught = '';
    my @err;
    retry {
        pass("try $count");
        die "ick" if ++$count < 13;
    }
    catch {
        $caught = $_;
    };
    is( $count, 10, "correct number of retries" );
    like( $caught, qr/^ick/, "caught exception when retries failed" );
};

subtest 'default retry and succeed' => sub {
    my $count  = 0;
    my $caught = '';
    my @err;
    retry {
        pass("try $count");
        die "ick" if ++$count < 6;
    }
    catch {
        $caught = $_;
    };
    is( $count,  6,  "correct number of retries" );
    is( $caught, "", "no exceptions caught" );
};

done_testing;
# COPYRIGHT

# vim: ts=4 sts=4 sw=4 et:
