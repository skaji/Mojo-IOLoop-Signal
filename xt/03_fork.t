use strict;
use warnings;
use Test2::IPC;
use Test::More;
use Test::Deep;
use Time::HiRes ();

our @pre_sync  = qw(TERM HUP);
our @post_sync = qw(INT TERM QUIT);

sub note_sig;
sub send_sig;
sub got_sig;

# sender
sub parent_run {
    my $child_pid = shift;
    my $sync;

    $SIG{HUP} = sub { note_sig 'sender', 'got', 'HUP'; $sync++ };

    for my $name (@pre_sync) {
        Time::HiRes::sleep(0.2);
        send_sig('sender', $name, $child_pid);
    }

    # wait for sync
    my $start = now();

    while (!$sync) {
        Time::HiRes::sleep(0.1);
        if (now() - $start > 3) {
            fail 'sync timeout';
            send_sig('sender', 'QUIT', $child_pid);
            return;
        }
    }

    note 'synchronized';

    for my $name (@post_sync) {
        Time::HiRes::sleep(0.2);
        send_sig('sender', $name, $child_pid);
    }
}

# parent / child
sub child_run {
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
    Mojo::IOLoop::Signal->on(INT  => sub { got_sig($who, 'INT', \%got)  });
    Mojo::IOLoop::Signal->on(QUIT => sub { 
        note_sig $who, 'got', 'QUIT';
        Mojo::IOLoop->remove($t); 
        Mojo::IOLoop::Signal->stop;
    });
    Mojo::IOLoop::Signal->on(HUP  => sub { 
        got_sig($who, 'HUP', \%got);
		if ($who eq 'prefork') {
			note "synchronize"; 
			if ($pids{child} = fork // die $!) {
				note "fork";
				send_sig(($who = 'parent'), 'HUP', $pids{sender});
			} else {
				$who = 'child';
			}
		}
    });
    Mojo::IOLoop->start;

    if ($who eq 'prefork') {
        fail "failed to fork!";
    } elsif ($who eq 'parent') {
        note 'parent';
        cmp_deeply $got{prefork}, [qw/TERM HUP/], 'got signals in order before forking';
        cmp_deeply $got{parent},  [qw/INT TERM/], 'got signals in order as parent';
        cmp_deeply $got{child},   [],             'no signals expected as child';
        send_sig $who, 'QUIT', $pids{child};
        waitpid $pids{child}, 0;
    } elsif ($who eq 'child') {
        note 'child';
        cmp_deeply $got{prefork}, [qw/TERM HUP/], 'got signals in order before forking';
        cmp_deeply $got{parent},  [],             'no signals expected as parent';
        cmp_deeply $got{child},   [],             'no signals expected as child';
    } else {
        die;
    }

    return 0;
};

sub run {
    my %pids;
    $pids{parent} = $$;
    $pids{child} = fork // die $!;
    if ($pids{child} == 0) {
        exit child_run($pids{parent}, $ENV{MOJO_REACTOR} = $_[0]);
    } else {
        parent_run($pids{child});
        waitpid $pids{child}, 0;
        is $?, 0;
    }
}

sub send_sig {
    my ($who, $signal, $pid) = @_;
    note_sig $who, 'send', $signal;
    kill $signal => $pid;
}

sub got_sig {
    my ($who, $signal, $got) = @_;
    push @{$got->{$who}}, $signal;
    note_sig $who, 'got', $signal;
}

sub note_sig {
    my ($who, $what, $sig) = @_;
    my $arrow = $what eq 'send'
        ? '->'
        : $what eq 'got'
        ? '<-'
        : die;
    note sprintf "%-7s %s %-4s %s", $who, $arrow, $what, $sig;
}

sub now() {
    Time::HiRes::clock_gettime(Time::HiRes::CLOCK_REALTIME());
}

subtest poll => sub { run('Mojo::Reactor::Poll') };
subtest ev   => sub { run('Mojo::Reactor::EV') };

done_testing;
