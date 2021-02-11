use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test2::IPC;
use Test::More;
use Test::Deep;
use Test::Utils qw(test_run send_sig got_sig);

sub run {
	test_run(shift, [
		{ recv => [ qw(USR1) ] },          # sender waits for child to signal start
		{ send => [ qw(TERM USR2) ] },     # sender sends signals
		{ recv => [ qw(USR1) ] },          # sender waits for child to signal start
		{ send => [ qw(INT TERM QUIT) ] }, # sender sends signals
	], sub {
		require Mojo::IOLoop::Signal;

		my %pids    = ( sender => shift, parent => $$ );
		my $reactor = shift;
		my $who     = 'prefork';
		my %got     = ( 
			prefork => [],
			parent  => [],
			child   => [],
		);

		is ref Mojo::IOLoop->singleton->reactor, $reactor, "using $reactor";

		my $t = Mojo::IOLoop->timer(3 => sub { fail 'timeout'; Mojo::IOLoop->stop });
		Mojo::IOLoop::Signal->on(TERM => sub { got_sig($who, 'TERM', \%got) });
		Mojo::IOLoop::Signal->on(INT  => sub { got_sig($who, 'INT',  \%got) });
		Mojo::IOLoop::Signal->on(QUIT => sub { 
			got_sig($who, 'QUIT', \%got);
			Mojo::IOLoop->remove($t); 
			Mojo::IOLoop::Signal->stop;
		});
		Mojo::IOLoop::Signal->on(USR2  => sub { 
			got_sig($who, 'USR2', \%got);
			if ($who eq 'prefork') {
				if ($pids{child} = fork // die $!) {
					note "fork";
					send_sig(($who = 'parent'), 'USR1', $pids{sender});
				} else {
					$who = 'child';
				}
			}
		});
		Mojo::IOLoop->next_tick(sub { 
			note 'signal start'; 
			send_sig($who, 'USR1', $pids{sender});
		});
		Mojo::IOLoop->start;

		if ($who eq 'prefork') {
			fail "failed to fork!";
		} elsif ($who eq 'parent') {
			note 'parent';
			cmp_deeply $got{prefork}, [qw/TERM USR2/],     'got signals in order before forking';
			cmp_deeply $got{parent},  [qw/INT TERM QUIT/], 'got signals in order as parent';
			cmp_deeply $got{child},   [],                  'no signals expected as child';
			send_sig($who, 'QUIT', $pids{child});
			waitpid $pids{child}, 0;
			is $?, 0, 'exit 0';
		} elsif ($who eq 'child') {
			note 'child';
			cmp_deeply $got{prefork}, [qw/TERM USR2/], 'got signals in order before forking';
			cmp_deeply $got{parent},  [],              'no signals expected as parent';
			cmp_deeply $got{child},   [qw/QUIT/],      'no signals expected as child';
		}

		return 0;
	});
}

subtest poll => sub { run('Mojo::Reactor::Poll') };
subtest ev   => sub { run('Mojo::Reactor::EV') };

done_testing;
