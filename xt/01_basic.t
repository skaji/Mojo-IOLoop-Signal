use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test2::IPC;
use Test::More;
use Test::Utils qw(test_run send_sig got_sig);

sub run {
	test_run(shift, [
		{ recv => [ qw(USR1) ] },               # sender waits for child to signal start
		{ send => [ qw(TERM INT TERM QUIT) ] }, # sender sends signals
	], sub {
		require Mojo::IOLoop::Signal;

		my %got     = ( child  => [] );
		my %pids    = ( sender => shift );
		my $reactor = shift;

		is ref Mojo::IOLoop->singleton->reactor, $reactor, "using $reactor";

		Mojo::IOLoop::Signal->on(TERM => sub { got_sig 'child', 'TERM', \%got; });
		Mojo::IOLoop::Signal->on(INT  => sub { got_sig 'child', 'INT',  \%got; });
		Mojo::IOLoop::Signal->on(QUIT => sub { got_sig 'child', 'QUIT', \%got; Mojo::IOLoop::Signal->stop });
		Mojo::IOLoop->next_tick(sub { 
			note 'signal start';
			send_sig 'child', 'USR1', $pids{sender};
		});
		Mojo::IOLoop->start;

		is scalar(@{$got{child}}), 4;
		is $got{child}[0], 'TERM';
		is $got{child}[1], 'INT';
		is $got{child}[2], 'TERM';
		is $got{child}[3], 'QUIT';

		return 0;
	});
}

subtest poll => sub { run('Mojo::Reactor::Poll') };
subtest ev   => sub { run('Mojo::Reactor::EV') };

done_testing;
