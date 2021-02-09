use strict;
use warnings;
use Test2::IPC;
use Test::More;
use Test::Deep;
use Time::HiRes ();

our @signals = qw(HUP TERM INT TERM QUIT);

sub child_run {
    require Mojo::IOLoop::Signal;

    is ref Mojo::IOLoop->singleton->reactor, $_[0], "using $_[0]";

    my $pid;
    my $who = 'prefork';
    my %got = ( 
        prefork => [],
        parent  => [],
        child   => [],
    );
    Mojo::IOLoop::Signal->on(HUP  => sub { 
        note "<- got HUP"; 
        push @{$got{$who}}, 'HUP';
        note "synchronize"; 
        Mojo::IOLoop->timer(0.25 => sub {
            $pid = fork // die $!;
            if ($pid) {
                note "fork";
                $who = 'parent';
            } else {
                $who = 'child';
            }
        });
    });
    my $t = Mojo::IOLoop->timer(3 => sub { Mojo::IOLoop->stop });
    Mojo::IOLoop::Signal->on(TERM => sub { note "<- got TERM"; push @{$got{$who}}, 'TERM' });
    Mojo::IOLoop::Signal->on(INT  => sub { note "<- got INT";  push @{$got{$who}}, 'INT'  });
    Mojo::IOLoop::Signal->on(QUIT => sub { 
        note "<- got QUIT"; 
        Mojo::IOLoop->remove($t); 
        Mojo::IOLoop::Signal->stop;
    });
    Mojo::IOLoop->start;

    if (!defined $pid) {
        fail "failed to fork!";
    } elsif ($pid) {
        note 'parent';
        cmp_deeply $got{prefork}, [qw/HUP TERM/], 'got signals in order before forking';
        cmp_deeply $got{parent},  [qw/INT TERM/], 'got signals in order as parent';
        cmp_deeply $got{child},   [],             'no signals expected as child';
        kill QUIT => $pid; 
        waitpid $pid, 0;
    } else {
        note 'child';
        cmp_deeply $got{prefork}, [qw/HUP TERM/], 'got signals in order before forking';
        cmp_deeply $got{parent},  [],             'no signals expected as parent';
        cmp_deeply $got{child},   [],             'no signals expected as child';
    }

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
