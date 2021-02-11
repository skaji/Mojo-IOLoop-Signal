package Test::Utils;

use strict;
use warnings;
use base 'Exporter';

use Test::More;
use Time::HiRes ();

our @EXPORT_OK = qw(test_run send_sig got_sig note_sig);

sub note_sig {
    my ($who, $what, $sig) = @_;
    my $arrow = $what eq 'send'
        ? '->'
        : $what eq 'got'
        ? '<-'
        : die;
    note sprintf "%-7s %s %-4s %s", $who, $arrow, $what, $sig;
}

sub send_sig {
    my ($who, $signal, $pid) = @_;
    note_sig($who, 'send', $signal);
    kill $signal => $pid;
}

sub got_sig {
    my ($who, $signal, $got) = @_;
    push @{$got->{$who}}, $signal;
    note_sig($who, 'got', $signal);
}

sub test_run {
    my ($reactor, $steps, $child_run) = @_;
    my %pids;
    $pids{parent} = $$;
    $pids{child} = fork // die $!;
    if ($pids{child} == 0) {
        exit $child_run->($pids{parent}, $ENV{MOJO_REACTOR} = $reactor);
    } else {
        sender_run($pids{child}, @$steps);
        waitpid $pids{child}, 0;
        is $?, 0, 'exit 0';
    }
}

# private

sub sender_run {
    my $child_pid = shift;

	# setup signal receivers

	my @got;
	my %sigs;
	for my $step (@_) {
		for my $action (keys %$step) {
			if ($action eq 'recv') {
				for (@{$step->{$action}}) {
					$sigs{$_}++;
				}
			}
		}
	}

	for (keys %sigs) {
		$SIG{$_} = sub { note_sig('sender', 'got', $_[0]); push @got, $_[0]; };
	}

	# send / recv

    for my $step (@_) {

		my @actions = sort keys %$step;

		if (@actions > 1) {
			die "expected send / recv, got: " . join ", ", @actions;
		}

		for my $action (@actions) {

			if ($action eq 'recv') {

				my @expect = @{$step->{$action}};

				while (@expect) {

					my $start = now();

					while (1) {

						Time::HiRes::sleep(0.1);

						if (now() - $start > 3) {
							fail 'sync timeout';
							send_sig('sender', 'QUIT', $child_pid);
							return;
						}

						if (@got) {
							if ($got[0] eq $expect[0]) {
								shift @got;
								last;
							} else {
								fail "expected $expect[0] got $got[0]";
								send_sig('sender', 'QUIT', $child_pid);
								return;
							}
						}
					}
					
					shift @expect;
				}

			} elsif ($action eq 'send') {

				for my $signal (@{$step->{$action}}) {
					Time::HiRes::sleep(0.2);
					send_sig('sender', $signal, $child_pid);
				}

			} else {

				die "expected send / recv, got: $action";
			}
		}
    }
}

sub now() {
    Time::HiRes::clock_gettime(Time::HiRes::CLOCK_REALTIME());
}

1;
