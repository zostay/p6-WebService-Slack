#!/usr/bin/env perl6
use v6;

use Test;
use lib 't/lib';
use WebService::Slack::WebAPI::Test;

my $api = WebService::Slack::WebAPI::Test.new(
    token => 'xoxt-blah',
);

$api.api.test(
    error => 'test',
    foo   => 'bar',
);

my %req = $api.test-results.shift;
is $api.test-results.elems, 0, 'only one request';
ok !%req<defined>, 'request on type, not object';
is %req<action>, 'api.test', 'action is api.test';
is %req<args>.elems, 2, 'got two args';
is %req<args><error>, 'test', 'error = test';
is %req<args><foo>, 'bar', 'foo = bar';
is %req<base-url>, 'https://slack.com/api/', 'got base-url';

done-testing;
