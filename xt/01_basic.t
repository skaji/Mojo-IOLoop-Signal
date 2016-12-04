use strict;
use warnings;
use Test2::IPC;
use Test::More;
use Time::HiRes ();

my $test = sub {
    require Mojo::IOLoop::Signal;

    my @got;
    Mojo::IOLoop::Signal->on(TERM => sub { note "<- got TERM"; push @got, 'TERM' });
    Mojo::IOLoop::Signal->on(INT  => sub { note "<- got INT";  push @got, 'INT'  });
    Mojo::IOLoop::Signal->on(QUIT => sub { note "<- got QUIT"; Mojo::IOLoop::Signal->stop });
    Mojo::IOLoop->start;

    is @got, 3;
    is $got[0], 'TERM';
    is $got[1], 'INT';
    is $got[2], 'TERM';
    done_testing;
    exit;
};

subtest poll => sub {
    my $pid = fork // die;
    if ($pid == 0) {
        $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
        $test->();
    } else {
        for my $name (qw(TERM INT TERM QUIT)) {
            Time::HiRes::sleep(0.2); # XXX
            note "-> send $name";
            kill $name => $pid;
        }
        waitpid $pid, 0;
        is $?, 0;
    }
};

subtest ev => sub {
    my $pid = fork // die;
    if ($pid == 0) {
        $ENV{MOJO_REACTOR} = 'Mojo::Reactor::EV';
        $test->();
    } else {
        for my $name (qw(TERM INT TERM QUIT)) {
            Time::HiRes::sleep(0.2); # XXX
            note "-> send $name";
            kill $name => $pid;
        }
        waitpid $pid, 0;
        is $?, 0;
    }
};

done_testing;
