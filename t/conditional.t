use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings;
use Test::Fatal;
binmode( Test::More->builder->$_, ":utf8" )
  for qw/output failure_output todo_output/;

use Try::Tiny::Retry qw/:all/;
$Try::Tiny::Retry::DEFAULT_DELAY = 10; # shorten default delay

subtest 'conditional not satisfied' => sub {
    my $count  = 0;
    my $caught = '';
    my @err;
    retry {
        pass("try $count");
        $count++;
        die "ick";
    }
    retry_if { /^oops/ }
    catch {
        $caught = $_;
    };
    is( $count, 1, "correct number of retries" );
    like( $caught, qr/^ick/, "caught expected error" );
};

subtest 'conditional not satisfied' => sub {
    my $count  = 0;
    my $caught = '';
    my @err;
    retry {
        pass("try $count");
        $count++;
        die "oops" if $count < 6;
        die "ick"  if $count >= 6;
    }
    retry_if { /^oops/ }
    catch {
        $caught = $_;
    };
    is( $count, 6, "correct number of retries" );
    like( $caught, qr/^ick/, "caught expected error" );
};

done_testing;
# COPYRIGHT

# vim: ts=4 sts=4 sw=4 et:
