use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test2::IPC;
use Test::More;
use Test::Utils qw(test_run);

our %signals = (
    HUP  => sub { }, # XXX some annoymous subs for checking restore
    TERM => sub { },
    QUIT => sub { },
    INT  => sub { },
);

sub run {
	test_run(shift, [], sub {
		require Mojo::IOLoop::Signal;

		is ref Mojo::IOLoop->singleton->reactor, $_[1], "using $_[1]";

		# NOTE replacement of %SIG only happens for Mojo::Reactor::Poll
		
		my @sig = sort keys %signals;

		# setup

		for my $sig (@sig) {
			$SIG{$sig} = $signals{$sig};
		}

		# replace

		for my $sig (@sig) {
			Mojo::IOLoop::Signal->singleton->on($sig => sub { });
		}

		# restore

		for my $sig (@sig) {
			Mojo::IOLoop::Signal->singleton->unsubscribe($sig);
		}

		# check

		for my $sig (@sig) {
			my $cb = $SIG{$sig};
			is $cb, $signals{$sig}, "restored $sig";
		}

		return 0;
	});
};

subtest poll => sub { run('Mojo::Reactor::Poll') };
subtest ev   => sub { run('Mojo::Reactor::EV') };

done_testing;
