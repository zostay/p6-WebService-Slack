unit class WebService::Slack::WebAPI;
use v6;

use HTTP::UserAgent;
use JSON::Tiny;

class GLOBAL::X::WebService::Slack::Exception is Exception {
}

class GLOBAL::X::WebService::Slack::APIException is Exception {
    has %.slack-message;
    has $.error-message;

    submethod BUILD(:%!slack-message, :%errors) {
        if %errors{ %!slack-message<error> }:exists {
            $!error-message = %errors{ %!slack-message<error> };
        }
        else {
            $!error-message = %!slack-message<error>.trans('_' => ' ').tc;
        }
    }

    method error-code { %!slack-message<error> }
    method message { $!error-message }
}

class GLOBAL::X::WebService::Slack::CommunicationException is Exception {
    has HTTP::Request $.request;
    has HTTP::Response $.response;
}

has HTTP::UserAgent $.ua = HTTP::UserAgent.new;
has Str $.base-url = 'https://slack.com/api/';
has Str $.token is required;

subset SlackChannel of Str where / ^ C <[0..9 A..F a..f]>+ $ /;
subset SlackDirect  of Str where / ^ D <[0..9 A..F a..f]>+ $ /;
subset SlackGroup   of Str where / ^ G <[0..9 A..F a..f]>+ $ /;
subset SlackUser    of Str where / ^ U <[0..9 A..F a..f]>+ $ /;
subset Timestamp    of UInt;

multi method request(::?CLASS:D: $action, *%args, :$base-url = $!base-url, :%errors) {
    my %form = |%args, :$!token;
    $?CLASS.request($action, |%form, :$base-url, :%errors);
}

multi method request(::?CLASS:U: $action, *%args, :$base-url = $!base-url, :%errors) {
    my $res = $!ua.post($base-url ~ $action, %args);

    my $slack-message = from-json($res.content);

    unless $slack-message<ok> {
        die X::WebService::Slack::APIException.new(:$slack-message, :%errors);
    }

    return $slack-message;
}

class Base {
    has $.api;
}

