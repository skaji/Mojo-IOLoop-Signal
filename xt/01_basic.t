use strict;
use warnings;
use Test2::IPC;
use Test::More;
use Time::HiRes ();

my $test = sub {
    my $write = shift;
    require Mojo::IOLoop;
    require Mojo::IOLoop::Signal;

    my $tick = sub { syswrite $write, "x\n" };

    my @got;
    Mojo::IOLoop::Signal->on(TERM => sub { note "<- got TERM"; push @got, 'TERM'; $tick->() });
    Mojo::IOLoop::Signal->on(INT  => sub { note "<- got INT";  push @got, 'INT'; $tick->()  });
    Mojo::IOLoop::Signal->on(QUIT => sub { note "<- got QUIT"; Mojo::IOLoop::Signal->stop });

    Mojo::IOLoop->timer(0 => $tick);
    Mojo::IOLoop->start;

    is @got, 3;
    is $got[0], 'TERM';
    is $got[1], 'INT';
    is $got[2], 'TERM';
};

subtest poll => sub {
    pipe my $read, my $write or die;
    my $pid = fork // die;
    if ($pid == 0) {
        close $read;
        $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
        $test->($write);
        exit;
    } else {
        close $write;
        my $tick = sub { scalar <$read> };
        for my $name (qw(TERM INT TERM QUIT)) {
            $tick->();
            note "-> send $name";
            kill $name => $pid;
        }
        waitpid $pid, 0;
        is $?, 0;
    }
};

subtest ev => sub {
    pipe my $read, my $write or die;
    my $pid = fork // die;
    if ($pid == 0) {
        close $read;
        $ENV{MOJO_REACTOR} = 'Mojo::Reactor::EV';
        $test->($write);
        exit;
    } else {
        close $write;
        my $tick = sub { scalar <$read> };
        for my $name (qw(TERM INT TERM QUIT)) {
            $tick->();
            note "-> send $name";
            kill $name => $pid;
        }
        waitpid $pid, 0;
        is $?, 0;
    }
};

done_testing;
