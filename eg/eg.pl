#!/usr/bin/env perl
use strict;
use warnings;
use lib "lib", "../lib";
use Mojo::IOLoop;
use Mojo::IOLoop::Signal;

warn "-> Please send me TERM signal by: kill $$\n";

Mojo::IOLoop::Signal->once(TERM => sub {
    my ($self, $name) = @_;
    warn "Got $name signal\n";
});

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
