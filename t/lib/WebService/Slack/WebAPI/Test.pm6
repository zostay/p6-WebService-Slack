use WebService::Slack::WebAPI;

unit class WebService::Slack::WebAPI::Test
    is WebService::Slack::WebAPI;
use v6;

has @.test-results;

multi method request(::?CLASS:D: $action, *%args, :$base-url = $.base-url, :%errors) {
    push @!test-results, {
        :defined, :$action, :%args, :$base-url, :%errors
    };
}

multi method request(::?CLASS:U: $action, *%args, :$base-url = $.base-url, :%errors) {
    push @!test-results, {
        :!defined, :$action, :%args, :$base-url, :%errors
    };
}
