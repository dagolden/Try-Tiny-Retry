use 5.006;
use strict;
use warnings;

package Try::Tiny::Retry;
# ABSTRACT: Extends Try::Tiny to allow retries
# VERSION

use parent 'Exporter';
our @EXPORT = qw(retry retry_if);
our @EXPORT_OK = ( @EXPORT, qw/delay delay_exp/ );

use Carp;
$Carp::Internal{ +__PACKAGE__ }++;

use Try::Tiny;

BEGIN {
    eval "use Sub::Name; 1" or *{subname} = sub { 1 }
}

sub retry(&;@) { ## no critic
    my ( $try, @code_refs ) = @_;

    # name the block if we have Sub::Name
    my $caller = caller;
    subname( "${caller}::retry {...} " => $try );

    my ( $delay, @conditions, @rest );

    # we need to save this here, the eval block will be in scalar context due
    # to $failed
    my $wantarray = wantarray;

    # find labeled blocks in the argument list: retry_if and delay tag by blessing
    foreach my $code_ref (@code_refs) {
        if ( ref($code_ref) eq 'Try::Tiny::Retry::RetryIf' ) {
            push @conditions, $code_ref;
        }
        elsif ( ref($code_ref) eq 'Try::Tiny::Retry::Delay' ) {
            croak 'A retry() may not be followed by multiple delay blocks'
              if $delay;
            $delay = $code_ref;
        }
        else {
            push @rest, $code_ref;
        }
    }

    $delay ||= delay_exp( [ 10, 100 ] ); # 10 times with 100 msec slot size

    my @ret;
    my $retry = sub {
        my $count = 0;
        while ( $count++ ) {
            try {
                # evaluate the try block in the correct context
                if ($wantarray) {
                    @ret = $try->();
                }
                elsif ( defined $wantarray ) {
                    $ret[0] = $try->();
                }
                else {
                    $try->();
                }
            }
            catch {
                my $err = $_;
                # if there are conditions, rethrow unless at least one is met
                if (@conditions) {
                    die $err unless grep { $_->($err) } @conditions;
                }
                # rethow if delay function signals stop with undef
                die $err unless defined $delay->($count);
            };
        }
        return $wantarray ? @ret : $ret[0];
    };

    return try( \&$retry, @rest );
}

sub retry_if(&;@) { ## no critic
    my ( $block, @rest ) = @_;
    return ( bless( \$block, 'Try::Tiny::Retry::RetryIf' ), @rest, );
}

sub delay(&;@) {    ## no critic
    my ( $block, @rest ) = @_;
    return ( bless( \$block, 'Try::Tiny::Retry::Delay' ), @rest, );
}

sub delay_exp($;@) { ## no critic
    my ( $params, @rest ) = @_;
    croak "delay_exp requires an array reference argument"
      unless ref($params) eq 'ARRAY';
    my ( $n, $scale ) = @$params;

    require Time::HiRes;

    my $delay = sub {
        return if $_[0] > $n;
        Time::HiRes::usleep( int rand( $scale * ( 1 << ( $_[0] - 1 ) ) ) );
    };

    return delay( \&$delay, @rest );
}

1;

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    use Try::Tiny::Retry;

=head1 DESCRIPTION

This module might be cool, but you'd never know it from the lack
of documentation.

=head1 USAGE

Good luck!

=head1 SEE ALSO

=for :list
* Maybe other modules do related things.

=cut

# vim: ts=4 sts=4 sw=4 et:
