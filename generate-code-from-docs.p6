#!/usr/bin/env perl6
use v6;

use IO::Glob;
use JSON::Tiny;

sub MAIN(
    $base-pm = "WebAPI.base.pm6",
    $slack-api-docs-dir = "slack-api-docs",
    $out-pm = "lib/WebService/Slack/WebAPI.pm6",
) {
    $*OUT = $out-pm.IO.open(:w);

    $base-pm.IO.slurp.say;

    my $g = glob("$slack-api-docs-dir/methods/*.json");

    my %sections;
    for glob("$slack-api-docs-dir/methods/*.json") -> $json {
        my $i = "$json".substr(23, *-5).rindex('.');
        my $section = "$json".substr(23, $i);
        my $method  = "$json".substr(23 + $i + 1, *-5);

        if $section ~~ /'.'/ {
            my ($base, $nested) = $section.split('.', 2);
            %sections{ $base }{ $nested } = { :$nested, :$section };
        }

        my %api-desc = from-json($json.slurp);

        %sections{ $section }{ $method } = %api-desc;
    }

    for %sections.sort».kv -> ($name, %methods) {
        render-class($name, %methods);
    }
}

my %type-map =
    bool         => [ '$', 'Bool' ],
    channel      => [ '$', 'SlackChannel' ],
    file         => [ '$', 'Str' ],
    file_comment => [ '$', 'Str' ],
    group        => [ '$', 'SlackGroup' ],
    im           => [ '$', 'SlackDirect' ],
    int          => [ '$', 'Int' ],
    mpim         => [ '$', 'SlackGroup' ],
    string       => [ '$', 'Str' ],
    # see https://github.com/slackhq/slack-api-docs/issues/7#issuecomment-67913241
    timestamp    => [ '$', 'Timestamp' ],
    user         => [ '$', 'SlackUser' ],
    users        => [ '@', 'SlackUser' ],
    UInt         => [ '$', 'UInt' ],
    ;

my %section-titles =
    api        => 'API',
    dnd        => 'DND',
    im         => 'IM',
    mpim       => 'MPIM',
    oauth      => 'OAuth',
    rtm        => 'RTM',
    usergroups => 'UserGroups',
    ;

sub render-class($name, %actions) {
    sub section-class-name($section is copy) {
        $section.=trans([ %section-titles.keys ] => [ %section-titles.values ]);
        $section.=subst(/<< . /, &tc, :g);
        $section.=trans([ '.' ] => [ '::' ]);
    }

    my $section = section-class-name($name);
    my $smiley  = $name eq 'api' | 'oauth' ?? '' !! ':D';
    my $class   = $section ~ $smiley;

    say qq/class $section is Base \{/;

    for %actions.sort».kv -> ($action, %spec is copy) {
        my $method = $action.subst(/ (.) (<[ A..Z ]>) /, -> $/ { "$0-{$1.lc}" }, :g);

        if %spec<nested> -> $nested {
            my $nested-method  = %spec<section>.split('.')[1];
            my $nested-section = section-class-name(%spec<section>);

            say qq:to/END_OF_NESTED_METHOD/.indent(4);
            #| Access the nested $nested-method object
            method $nested-method\($class:) \{
                state \$nested = $nested-section\.new(:\$.api);
                \$nested
            }
            END_OF_NESTED_METHOD

            next;
        }

        if %spec<has_paging>:delete {
            %spec<args><count> = {
                desc     => 'Number of items to return per page.',
                type     => 'UInt',
                required => False,
                default  => %spec<default_count>:delete,
            };

            %spec<args><page> = {
                desc     => 'Page number of results to return.',
                type     => 'UInt',
                required => False,
                default  => 1,
            };
        }

        elsif %spec<default_count>:delete {
            # ignore, since slack appears to ignore when this happens
        }

        my (@sig, @cap);
        my %spec-args := %spec<args>:delete // {};
        for %spec-args.sort».kv -> ($arg is copy, %arg-spec is copy) {
            $arg .= trans('_' => '-');
            my $required = %arg-spec<required>:delete ?? '!' !! '';

            my ($sigil, $type);
            if %arg-spec<type>:exists {
                ($sigil, $type) = %type-map{ my $as-type = %arg-spec<type>:delete };
                die "Unknown type $as-type in $section.$method :\$$arg"
                    without $type;
                $type ~= ' ';
            }
            else {
                $sigil = '$';
                $type  = '';
            }

            if $arg ~~ /[ ^ | '-' ] ts [ $ | '-' ]/ {
                $type ||= 'Timestamp ';
            }

            my $default = do given %arg-spec<default>:delete // '' {
                when '' { $_ }
                when /^ \d+ $/ {
                    $type ||= 'Int ';
                    $_;
                }
                when 'all' {
                    $type ||= 'Str ';
                    "'$_'";
                }
                when 'now' {
                    $type ||= 'Timestamp ';
                    $_;
                }
                when 'score' {
                    $type ||= 'Str ';
                    "'$_'";
                }
                when 'desc' {
                    $type ||= 'Str ';
                    "'$_'";
                }
                default { "'$_'" }
            }
            $default = $default ?? " = $default" !! '';

            my $desc = %arg-spec<desc>:delete;
            if $desc ~~ /\n/ {
                $desc.=subst(/\n/, "\n{' ' x 35}#= ", :g);
            }

            push @sig, sprintf "    %-30s #= %s",
                "$type:$sigil$arg$required$default,",
                $desc,
                ;

            push @cap, ":$sigil$arg";

            # ignore example, it's for docs only
            %arg-spec<example>:delete;

            die "Failed to account for {%arg-spec.keys} in $section.$method"
                if %arg-spec.keys;
        }

        push @sig, sprintf "    %-30s #= %s",
            "*%args,",
            "Any other arguments we don't know about."
            ;

        my $sig = @sig.join("\n");
        my $cap = @cap.join(", ");
        $cap ~= ', ' if $cap;

        my $DEPRECATED = %spec<deprecated>:delete ?? ' is DEPRECATED' !! '';

        my %errors = %spec<errors>:delete // ();
        my $errors = %errors ?? "{%errors.perl}" !! '%';

        say qq:to/END_OF_METHOD/.indent(4);
        #| {%spec<desc>:delete}
        method $method\($class: \n$sig\n)$DEPRECATED \{
            my %errors := $errors;
            \$.api.request('$name.$action', :%errors, $cap|%args);
        }

        END_OF_METHOD

        die "Failed to account for {%spec.keys} {%spec.perl} in $name"
            if %spec.keys;
    }

    say qq/}\n/;

    next if $section ~~ /'::'/;

    if $smiley {
        say qq:to/END_OF_ACCESSOR/;
        #| Accessor for $name object
        method $name\(::?CLASS:D:) returns $class \{
            state \$object = $section.new\(api => self);
            \$object;
        }
        END_OF_ACCESSOR
    }
    else {
        say qq:to/END_OF_ACCESSOR/;
        #| Accessor for $name object
        method $name\(::?CLASS:) returns $class \{
            dd self.WHAT;
            state \$object = $section.new\(api => self.WHAT);
            \$object;
        }
        END_OF_ACCESSOR
    }
}
