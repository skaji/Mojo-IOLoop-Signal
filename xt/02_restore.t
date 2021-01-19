use strict;
use warnings;
use Test2::IPC;
use Test::More;
use Time::HiRes ();

our %signals = (
    HUP  => sub { }, # XXX some annoymous subs for checking restore
    TERM => sub { },
    QUIT => sub { },
    INT  => sub { },
);

sub child_run {
    require Mojo::IOLoop::Signal;

    is ref Mojo::IOLoop->singleton->reactor, $_[0], "using $_[0]";

    # NOTE replacement of %SIG only happens for Mojo::Reactor::Poll

    # setup

    for my $sig (sort keys %signals) {
        $SIG{$sig} = $signals{$sig};
    }

    # replace

    for my $sig (sort keys %signals) {
        Mojo::IOLoop::Signal->singleton->on($sig => sub { });
    }

    # restore

    for my $sig (sort keys %signals) {
        Mojo::IOLoop::Signal->singleton->unsubscribe($sig);
    }

    # check

    for my $sig (sort keys %signals) {
        my $cb = $SIG{$sig};
        is $cb, $signals{$sig}, "restored $sig";
    }

    return 0;
};

sub parent_run {
    # nothing to do
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
