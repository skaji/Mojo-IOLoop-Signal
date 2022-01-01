[![Actions Status](https://github.com/skaji/Mojo-IOLoop-Signal/workflows/test/badge.svg)](https://github.com/skaji/Mojo-IOLoop-Signal/actions)

# NAME

Mojo::IOLoop::Signal - Non-blocking signal handler

# SYNOPSIS

    use Mojo::IOLoop::Signal;

    Mojo::IOLoop::Signal->on(TERM => sub {
      my ($self, $name) = @_;
      warn "Got $name signal";
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

# DESCRIPTION

Mojo::IOLoop::Signal is a Mojo::IOLoop based, non-blocking signal handler.

# EVENTS

Mojo::IOLoop::Signal inherits all events from [Mojo::EventEmitter](https://metacpan.org/pod/Mojo%3A%3AEventEmitter) and can emit the following new ones.

## signal names such as TERM, INT, QUIT, ...

See `$Config{sig_name}` for a complete list.

    $ perl -MConfig -e 'print $Config{sig_name}'
    ZERO HUP INT QUIT ILL TRAP ABRT EMT FPE KILL BUS SEGV SYS PIPE ALRM TERM URG STOP TSTP CONT CHLD TTIN TTOU IO XCPU XFSZ VTALRM PROF WINCH INFO USR1 USR2 IOT

# METHODS

Mojo::IOLoop::Signal inherits all methods from [Mojo::EventEmitter](https://metacpan.org/pod/Mojo%3A%3AEventEmitter) and implements the following new ones.

## stop

    Mojo::IOLoop::Signal->stop;

Stop watching signals. You might want to use `stop` like:

    Mojo::IOLoop::Signal->on(HUP => sub {
      my ($self, $name) = @_;
      # log rotate
    });
    Mojo::IOLoop::Signal->on(TERM => sub {
      my ($self, $name) = @_;
      $self->stop;
    });
    Mojo::IOLoop->start;

# AUTHOR

Shoichi Kaji <skaji@cpan.org>

# COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
