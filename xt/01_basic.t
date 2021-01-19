use strict;
use warnings;
use Test2::IPC;
use Test::More;
use Time::HiRes ();

our @signals = qw(TERM INT TERM QUIT);

sub child_run {
    require Mojo::IOLoop::Signal;

    is ref Mojo::IOLoop->singleton->reactor, $_[0], "using $_[0]";

    my @got;
    Mojo::IOLoop::Signal->on(TERM => sub { note "<- got TERM"; push @got, 'TERM' });
    Mojo::IOLoop::Signal->on(INT  => sub { note "<- got INT";  push @got, 'INT'  });
    Mojo::IOLoop::Signal->on(QUIT => sub { note "<- got QUIT"; Mojo::IOLoop::Signal->stop });
    Mojo::IOLoop->start;

    is @got, 3;
    is $got[0], 'TERM';
    is $got[1], 'INT';
    is $got[2], 'TERM';

    return 0;
};

sub parent_run {
    for my $name (@signals) {
        Time::HiRes::sleep(0.2); # XXX
        note "-> send $name";
        kill $name => $_[0];
    }
}

sub run {
    my $pid = fork // die $!;
    if ($pid == 0) {
        exit child_run($ENV{MOJO_REACTOR} = $_[0]);
    } else {
        parent_run($pid);
        waitpid $pid, 0;
        is $?, 0;
    }
}

subtest poll => sub { run('Mojo::Reactor::Poll') };
subtest ev   => sub { run('Mojo::Reactor::EV') };

done_testing;
