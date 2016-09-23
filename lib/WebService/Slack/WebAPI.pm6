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


class API is Base {
    #| Checks API calling code.
    method test(API: 
        :$error,                       #= Error response to return
        :$foo,                         #= example property to return
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('api.test', :%errors, :$error, :$foo, |%args);
    }


}

#| Accessor for api object
method api(::?CLASS:) returns API {
    dd self.WHAT;
    state $object = API.new(api => self.WHAT);
    $object;
}

class Auth is Base {
    #| Checks authentication & identity.
    method test(Auth:D: 
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('auth.test', :%errors, |%args);
    }


}

#| Accessor for auth object
method auth(::?CLASS:D:) returns Auth:D {
    state $object = Auth.new(api => self);
    $object;
}

class Channels is Base {
    #| Archives a channel.
    method archive(Channels:D: 
        SlackChannel :$channel!,       #= Channel to archive
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:already_archived("Channel has already been archived."), :cant_archive_general("You cannot archive the general channel"), :channel_not_found("Value passed for `channel` was invalid."), :last_ra_channel("You cannot archive the last channel for a restricted account"), :restricted_action("A team preference prevents the authenticated user from archiving.")};
        $.api.request('channels.archive', :%errors, :$channel, |%args);
    }


    #| Creates a channel.
    method create(Channels:D: 
        :$name!,                       #= Name of channel to create
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:name_taken("A channel cannot be created with the given name."), :no_channel("Value passed for `name` was empty."), :restricted_action("A team preference prevents the authenticated user from creating channels.")};
        $.api.request('channels.create', :%errors, :$name, |%args);
    }


    #| Fetches history of messages and events from a channel.
    method history(Channels:D: 
        SlackChannel :$channel!,       #= Channel to fetch history for.
        Int :$count = 100,             #= Number of messages to return, between 1 and 1000.
        Int :$inclusive,               #= Include messages with latest or oldest timestamp in results.
        Timestamp :$latest = now,      #= End of time range of messages to include in results.
        Timestamp :$oldest = 0,        #= Start of time range of messages to include in results.
        Int :$unreads,                 #= Include `unread_count_display` in the output?
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_ts_latest("Value passed for `latest` was invalid"), :invalid_ts_oldest("Value passed for `oldest` was invalid")};
        $.api.request('channels.history', :%errors, :$channel, :$count, :$inclusive, :$latest, :$oldest, :$unreads, |%args);
    }


    #| Gets information about a channel.
    method info(Channels:D: 
        SlackChannel :$channel!,       #= Channel to get info on
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid.")};
        $.api.request('channels.info', :%errors, :$channel, |%args);
    }


    #| Invites a user to a channel.
    method invite(Channels:D: 
        SlackChannel :$channel!,       #= Channel to invite user to.
        SlackUser :$user!,             #= User to invite to channel.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:already_in_channel("Invited user is already in the channel."), :cant_invite("User cannot be invited to this channel."), :cant_invite_self("Authenticated user cannot invite themselves to a channel."), :channel_not_found("Value passed for `channel` was invalid."), :is_archived("Channel has been archived."), :not_in_channel("Authenticated user is not in the channel."), :user_not_found("Value passed for `user` was invalid.")};
        $.api.request('channels.invite', :%errors, :$channel, :$user, |%args);
    }


    #| Joins a channel, creating it if needed.
    method join(Channels:D: 
        :$name!,                       #= Name of channel to join
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :is_archived("Channel has been archived."), :name_taken("A channel cannot be created with the given name."), :no_channel("Value passed for `name` was empty."), :restricted_action("A team preference prevents the authenticated user from creating channels.")};
        $.api.request('channels.join', :%errors, :$name, |%args);
    }


    #| Removes a user from a channel.
    method kick(Channels:D: 
        SlackChannel :$channel!,       #= Channel to remove user from.
        SlackUser :$user!,             #= User to remove from channel.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_kick_from_general("User cannot be removed from #general."), :cant_kick_from_last_channel("User cannot be removed from the last channel they're in."), :cant_kick_self("Authenticated user can't kick themselves from a channel."), :channel_not_found("Value passed for `channel` was invalid."), :not_in_channel("User was not in the channel."), :restricted_action("A team preference prevents the authenticated user from kicking."), :user_not_found("Value passed for `user` was invalid.")};
        $.api.request('channels.kick', :%errors, :$channel, :$user, |%args);
    }


    #| Leaves a channel.
    method leave(Channels:D: 
        SlackChannel :$channel!,       #= Channel to leave
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_leave_general("Authenticated user cannot leave the general channel"), :channel_not_found("Value passed for `channel` was invalid."), :is_archived("Channel has been archived.")};
        $.api.request('channels.leave', :%errors, :$channel, |%args);
    }


    #| Lists all channels in a Slack team.
    method list(Channels:D: 
        Int :$exclude-archived,        #= Don't return archived channels.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('channels.list', :%errors, :$exclude-archived, |%args);
    }


    #| Sets the read cursor in a channel.
    method mark(Channels:D: 
        SlackChannel :$channel!,       #= Channel to set reading cursor in.
        Timestamp :$ts!,               #= Timestamp of the most recently seen message.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_timestamp("Value passed for `timestamp` was invalid."), :not_in_channel("Caller is not a member of the channel.")};
        $.api.request('channels.mark', :%errors, :$channel, :$ts, |%args);
    }


    #| Renames a channel.
    method rename(Channels:D: 
        SlackChannel :$channel!,       #= Channel to rename
        :$name!,                       #= New name for channel.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_name("New name is invalid"), :name_taken("New channel name is taken"), :not_authorized("Caller cannot rename this channel"), :not_in_channel("Caller is not a member of the channel.")};
        $.api.request('channels.rename', :%errors, :$channel, :$name, |%args);
    }


    #| Sets the purpose for a channel.
    method set-purpose(Channels:D: 
        SlackChannel :$channel!,       #= Channel to set the purpose of
        :$purpose!,                    #= The new purpose
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :is_archived("Channel has been archived."), :not_in_channel("Authenticated user is not in the channel."), :too_long("Purpose was longer than 250 characters."), :user_is_restricted("Setting the purpose is a restricted action.")};
        $.api.request('channels.setPurpose', :%errors, :$channel, :$purpose, |%args);
    }


    #| Sets the topic for a channel.
    method set-topic(Channels:D: 
        SlackChannel :$channel!,       #= Channel to set the topic of
        :$topic!,                      #= The new topic
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :is_archived("Channel has been archived."), :not_in_channel("Authenticated user is not in the channel."), :too_long("Topic was longer than 250 characters."), :user_is_restricted("Setting the topic is a restricted action.")};
        $.api.request('channels.setTopic', :%errors, :$channel, :$topic, |%args);
    }


    #| Unarchives a channel.
    method unarchive(Channels:D: 
        SlackChannel :$channel!,       #= Channel to unarchive
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :not_archived("Channel is not archived.")};
        $.api.request('channels.unarchive', :%errors, :$channel, |%args);
    }


}

#| Accessor for channels object
method channels(::?CLASS:D:) returns Channels:D {
    state $object = Channels.new(api => self);
    $object;
}

class Chat is Base {
    #| Deletes a message.
    method delete(Chat:D: 
        SlackChannel :$channel!,       #= Channel containing the message to be deleted.
        Timestamp :$ts!,               #= Timestamp of the message to be deleted.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_delete_message("Authenticated user does not have permission to delete this message."), :channel_not_found("Value passed for `channel` was invalid."), :compliance_exports_prevent_deletion("Compliance exports are on, messages can not be deleted"), :message_not_found("No message exists with the requested timestamp.")};
        $.api.request('chat.delete', :%errors, :$channel, :$ts, |%args);
    }


    #| Sends a message to a channel.
    method post-message(Chat:D: 
        :$as-user,                     #= Pass true to post the message as the authed user, instead of as a bot. Defaults to false. See [authorship](#authorship) below.
        :$attachments,                 #= Structured message attachments.
        SlackChannel :$channel!,       #= Channel, private group, or IM channel to send message to. Can be an encoded ID, or a name. See [below](#channels) for more details.
        :$icon-emoji,                  #= emoji to use as the icon for this message. Overrides `icon_url`. Must be used in conjunction with `as_user` set to false, otherwise ignored. See [authorship](#authorship) below.
        :$icon-url,                    #= URL to an image to use as the icon for this message. Must be used in conjunction with `as_user` set to false, otherwise ignored. See [authorship](#authorship) below.
        :$link-names,                  #= Find and link channel names and usernames.
        :$parse,                       #= Change how messages are treated. Defaults to `none`. See [below](#formatting).
        :$text!,                       #= Text of the message to send. See below for an explanation of [formatting](#formatting).
        :$unfurl-links,                #= Pass true to enable unfurling of primarily text-based content.
        :$unfurl-media,                #= Pass false to disable unfurling of media content.
        :$username,                    #= Set your bot's user name. Must be used in conjunction with `as_user` set to false, otherwise ignored. See [authorship](#authorship) below.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :is_archived("Channel has been archived."), :msg_too_long("Message text is too long"), :no_text("No message text provided"), :not_in_channel("Cannot post user messages to a channel they are not in."), :rate_limited("Application has posted too many messages, [read the Rate Limit documentation](/docs/rate-limits) for more information")};
        $.api.request('chat.postMessage', :%errors, :$as-user, :$attachments, :$channel, :$icon-emoji, :$icon-url, :$link-names, :$parse, :$text, :$unfurl-links, :$unfurl-media, :$username, |%args);
    }


    #| Updates a message.
    method update(Chat:D: 
        :$as-user,                     #= Pass true to update the message as the authed user. [Bot users](/bot-users) in this context are considered authed users.
        :$attachments,                 #= Structured message attachments.
        SlackChannel :$channel!,       #= Channel containing the message to be updated.
        :$link-names,                  #= Find and link channel names and usernames. Defaults to `none`. This parameter should be used in conjunction with `parse`. To set `link_names` to `1`, specify a `parse` mode of `full`.
        :$parse,                       #= Change how messages are treated. Defaults to `client`, unlike `chat.postMessage`. See [below](#formatting).
        :$text!,                       #= New text for the message, using the [default formatting rules](/docs/formatting).
        Timestamp :$ts!,               #= Timestamp of the message to be updated.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_update_message("Authenticated user does not have permission to update this message."), :channel_not_found("Value passed for `channel` was invalid."), :edit_window_closed("The message cannot be edited due to the team message edit settings"), :message_not_found("No message exists with the requested timestamp."), :msg_too_long("Message text is too long"), :no_text("No message text provided")};
        $.api.request('chat.update', :%errors, :$as-user, :$attachments, :$channel, :$link-names, :$parse, :$text, :$ts, |%args);
    }


}

#| Accessor for chat object
method chat(::?CLASS:D:) returns Chat:D {
    state $object = Chat.new(api => self);
    $object;
}

class DND is Base {
    #| Ends the current user's Do Not Disturb session immediately.
    method end-dnd(DND:D: 
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:unknown_error("There was a mysterious problem ending the user's Do Not Disturb session")};
        $.api.request('dnd.endDnd', :%errors, |%args);
    }


    #| Ends the current user's snooze mode immediately.
    method end-snooze(DND:D: 
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:snooze_end_failed("There was a problem setting the user's Do Not Disturb status"), :snooze_not_active("Snooze is not active for this user and cannot be ended")};
        $.api.request('dnd.endSnooze', :%errors, |%args);
    }


    #| Retrieves a user's current Do Not Disturb status.
    method info(DND:D: 
        Str :$user,                    #= User to fetch status for (defaults to current user)
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('dnd.info', :%errors, :$user, |%args);
    }


    #| Turns on Do Not Disturb mode for the current user, or changes its duration.
    method set-snooze(DND:D: 
        Int :$num-minutes!,            #= Number of minutes, from now, to snooze until.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:missing_duration("No value provided for `num_minutes`"), :snooze_failed("There was a problem setting the user's Do Not Disturb status")};
        $.api.request('dnd.setSnooze', :%errors, :$num-minutes, |%args);
    }


    #| Retrieves the Do Not Disturb status for users on a team.
    method team-info(DND:D: 
        Str :$users,                   #= Comma-separated list of users to fetch Do Not Disturb status for
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('dnd.teamInfo', :%errors, :$users, |%args);
    }


}

#| Accessor for dnd object
method dnd(::?CLASS:D:) returns DND:D {
    state $object = DND.new(api => self);
    $object;
}

class Emoji is Base {
    #| Lists custom emoji for a team.
    method list(Emoji:D: 
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('emoji.list', :%errors, |%args);
    }


}

#| Accessor for emoji object
method emoji(::?CLASS:D:) returns Emoji:D {
    state $object = Emoji.new(api => self);
    $object;
}

class Files is Base {
    #| Access the nested comments object
    method comments(Files:D:) {
        state $nested = Files::Comments.new(:$.api);
        $nested
    }

    #| Deletes a file.
    method delete(Files:D: 
        :$file!,                       #= ID of file to delete.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_delete_file("Authenticated user does not have permission to delete this file."), :file_deleted("The file has already been deleted."), :file_not_found("The file does not exist, or is not visible to the calling user.")};
        $.api.request('files.delete', :%errors, :$file, |%args);
    }


    #| Gets information about a team file.
    method info(Files:D: 
        UInt :$count = 100,            #= Number of items to return per page.
        :$file!,                       #= Specify a file by providing its ID.
        UInt :$page = 1,               #= Page number of results to return.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:file_deleted("The requested file has been deleted"), :file_not_found("Value passed for `file` was invalid")};
        $.api.request('files.info', :%errors, :$count, :$file, :$page, |%args);
    }


    #| Lists & filters team files.
    method list(Files:D: 
        SlackChannel :$channel,        #= Filter files appearing in a specific channel, indicated by its ID.
        UInt :$count = 100,            #= Number of items to return per page.
        UInt :$page = 1,               #= Page number of results to return.
        Timestamp :$ts-from = 0,       #= Filter files created after this timestamp (inclusive).
        Timestamp :$ts-to = now,       #= Filter files created before this timestamp (inclusive).
        Str :$types = 'all',           #= Filter files by type:
                                       #= 
                                       #= * `all` - All files
                                       #= * `posts` - Posts
                                       #= * `snippets` - Snippets
                                       #= * `images` - Image files
                                       #= * `gdocs` - Google docs
                                       #= * `zips` - Zip files
                                       #= * `pdfs` - PDF files
                                       #= 
                                       #= You can pass multiple values in the types argument, like `types=posts,snippets`.The default value is `all`, which does not filter the list.
        SlackUser :$user,              #= Filter files created by a single user.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:unknown_type("Value passed for `types` was invalid"), :user_not_found("Value passed for `user` was invalid")};
        $.api.request('files.list', :%errors, :$channel, :$count, :$page, :$ts-from, :$ts-to, :$types, :$user, |%args);
    }


    #| Revokes public/external sharing access for a file
    method revoke-public-uR-l(Files:D: 
        Str :$file!,                   #= File to revoke
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:file_not_found("Value passed for `file` was invalid")};
        $.api.request('files.revokePublicURL', :%errors, :$file, |%args);
    }


    #| Enables a file for public/external sharing.
    method shared-public-uR-l(Files:D: 
        Str :$file!,                   #= File to share
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:file_not_found("Value passed for `file` was invalid"), :not_allowed("Public sharing has been disabled for this team")};
        $.api.request('files.sharedPublicURL', :%errors, :$file, |%args);
    }


    #| Uploads or creates a file.
    method upload(Files:D: 
        SlackChannel :$channels,       #= Comma-separated list of channel names or IDs where the file will be shared.
        :$content,                     #= File contents via a POST var.
        Str :$file!,                   #= File contents via `multipart/form-data`.
        :$filename!,                   #= Filename of file.
        :$filetype,                    #= Slack-internal file type identifier.
        :$initial-comment,             #= Initial comment to add to file.
        :$title,                       #= Title of file.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:invalid_channel("One or more channels supplied are invalid"), :posting_to_general_channel_denied("An admin has restricted posting to the #general channel.")};
        $.api.request('files.upload', :%errors, :$channels, :$content, :$file, :$filename, :$filetype, :$initial-comment, :$title, |%args);
    }


}

#| Accessor for files object
method files(::?CLASS:D:) returns Files:D {
    state $object = Files.new(api => self);
    $object;
}

class Files::Comments is Base {
    #| Add a comment to an existing file.
    method add(Files::Comments:D: 
        :$comment!,                    #= Text of the comment to add.
        :$file!,                       #= File to add a comment to.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:file_deleted("The requested file was previously deleted."), :file_not_found("The requested file could not be found."), :no_comment("The `comment` field was empty.")};
        $.api.request('files.comments.add', :%errors, :$comment, :$file, |%args);
    }


    #| Deletes an existing comment on a file.
    method delete(Files::Comments:D: 
        :$file!,                       #= File to delete a comment from.
        :$id!,                         #= The comment to delete.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_delete("The requested comment could not be deleted."), :file_deleted("The requested file was previously deleted."), :file_not_found("The requested file could not be found.")};
        $.api.request('files.comments.delete', :%errors, :$file, :$id, |%args);
    }


    #| Edit an existing file comment.
    method edit(Files::Comments:D: 
        :$comment!,                    #= Text of the comment to edit.
        :$file!,                       #= File containing the comment to edit.
        :$id!,                         #= The comment to edit.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_edit("The requested file could not be found."), :edit_window_closed("The timeframe for editing the comment has expired."), :file_deleted("The requested file was previously deleted."), :file_not_found("The requested file could not be found."), :no_comment("The `comment` field was empty.")};
        $.api.request('files.comments.edit', :%errors, :$comment, :$file, :$id, |%args);
    }


}

class Groups is Base {
    #| Archives a private channel.
    method archive(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to archive
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:already_archived("Group has already been archived."), :channel_not_found("Value passed for `channel` was invalid."), :group_contains_others("Restricted accounts cannot archive groups containing others."), :last_ra_channel("You cannot archive the last channel for a restricted account."), :restricted_action("A team preference prevents the authenticated user from archiving.")};
        $.api.request('groups.archive', :%errors, :$channel, |%args);
    }


    #| Closes a private channel.
    method close(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to close.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid.")};
        $.api.request('groups.close', :%errors, :$channel, |%args);
    }


    #| Creates a private channel.
    method create(Groups:D: 
        :$name!,                       #= Name of private channel to create
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:name_taken("A group cannot be created with the given name."), :no_channel("No group name was passed."), :restricted_action("A team preference prevents the authenticated user from creating groups.")};
        $.api.request('groups.create', :%errors, :$name, |%args);
    }


    #| Clones and archives a private channel.
    method create-child(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to clone and archive.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:already_archived("An archived group cannot be cloned"), :channel_not_found("Value passed for `channel` was invalid."), :restricted_action("A team preference prevents the authenticated user from creating groups.")};
        $.api.request('groups.createChild', :%errors, :$channel, |%args);
    }


    #| Fetches history of messages and events from a private channel.
    method history(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to fetch history for.
        Int :$count = 100,             #= Number of messages to return, between 1 and 1000.
        Int :$inclusive,               #= Include messages with latest or oldest timestamp in results.
        Timestamp :$latest = now,      #= End of time range of messages to include in results.
        Timestamp :$oldest = 0,        #= Start of time range of messages to include in results.
        Int :$unreads,                 #= Include `unread_count_display` in the output?
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_ts_latest("Value passed for `latest` was invalid"), :invalid_ts_oldest("Value passed for `oldest` was invalid")};
        $.api.request('groups.history', :%errors, :$channel, :$count, :$inclusive, :$latest, :$oldest, :$unreads, |%args);
    }


    #| Gets information about a private channel.
    method info(Groups:D: 
        SlackChannel :$channel!,       #= Private channel to get info on
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid.")};
        $.api.request('groups.info', :%errors, :$channel, |%args);
    }


    #| Invites a user to a private channel.
    method invite(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to invite user to.
        SlackUser :$user!,             #= User to invite.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_invite("User cannot be invited to this group."), :cant_invite_self("Authenticated user cannot invite themselves to a group."), :channel_not_found("Value passed for `channel` was invalid."), :is_archived("Group has been archived."), :user_not_found("Value passed for `user` was invalid.")};
        $.api.request('groups.invite', :%errors, :$channel, :$user, |%args);
    }


    #| Removes a user from a private channel.
    method kick(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to remove user from.
        SlackUser :$user!,             #= User to remove from private channel.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_kick_self("You can't remove yourself from a group"), :channel_not_found("Value passed for `channel` was invalid."), :not_in_group("User or caller were are not in the group"), :restricted_action("A team preference prevents the authenticated user from kicking."), :user_not_found("Value passed for `user` was invalid.")};
        $.api.request('groups.kick', :%errors, :$channel, :$user, |%args);
    }


    #| Leaves a private channel.
    method leave(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to leave
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:cant_leave_last_channel("Authenticated user cannot leave the last channel they are in"), :channel_not_found("Value passed for `channel` was invalid."), :is_archived("Group has been archived."), :last_member("Authenticated user is the last member of a group and cannot leave it")};
        $.api.request('groups.leave', :%errors, :$channel, |%args);
    }


    #| Lists private channels that the calling user has access to.
    method list(Groups:D: 
        Int :$exclude-archived,        #= Don't return archived private channels.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('groups.list', :%errors, :$exclude-archived, |%args);
    }


    #| Sets the read cursor in a private channel.
    method mark(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to set reading cursor in.
        Timestamp :$ts!,               #= Timestamp of the most recently seen message.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_timestamp("Value passed for `timestamp` was invalid.")};
        $.api.request('groups.mark', :%errors, :$channel, :$ts, |%args);
    }


    #| Opens a private channel.
    method open(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to open.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid.")};
        $.api.request('groups.open', :%errors, :$channel, |%args);
    }


    #| Renames a private channel.
    method rename(Groups:D: 
        SlackChannel :$channel!,       #= Private channel to rename
        :$name!,                       #= New name for private channel.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_name("New name is invalid"), :name_taken("New channel name is taken")};
        $.api.request('groups.rename', :%errors, :$channel, :$name, |%args);
    }


    #| Sets the purpose for a private channel.
    method set-purpose(Groups:D: 
        SlackChannel :$channel!,       #= Private channel to set the purpose of
        :$purpose!,                    #= The new purpose
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :is_archived("Private group has been archived"), :too_long("Purpose was longer than 250 characters."), :user_is_restricted("Setting the purpose is a restricted action.")};
        $.api.request('groups.setPurpose', :%errors, :$channel, :$purpose, |%args);
    }


    #| Sets the topic for a private channel.
    method set-topic(Groups:D: 
        SlackChannel :$channel!,       #= Private channel to set the topic of
        :$topic!,                      #= The new topic
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :is_archived("Private group has been archived"), :too_long("Topic was longer than 250 characters."), :user_is_restricted("Setting the topic is a restricted action.")};
        $.api.request('groups.setTopic', :%errors, :$channel, :$topic, |%args);
    }


    #| Unarchives a private channel.
    method unarchive(Groups:D: 
        SlackGroup :$channel!,         #= Private channel to unarchive
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :not_archived("Group is not archived.")};
        $.api.request('groups.unarchive', :%errors, :$channel, |%args);
    }


}

#| Accessor for groups object
method groups(::?CLASS:D:) returns Groups:D {
    state $object = Groups.new(api => self);
    $object;
}

class IM is Base {
    #| Close a direct message channel.
    method close(IM:D: 
        SlackDirect :$channel!,        #= Direct message channel to close.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :user_does_not_own_channel("Calling user does not own this DM channel.")};
        $.api.request('im.close', :%errors, :$channel, |%args);
    }


    #| Fetches history of messages and events from direct message channel.
    method history(IM:D: 
        SlackDirect :$channel!,        #= Direct message channel to fetch history for.
        Int :$count = 100,             #= Number of messages to return, between 1 and 1000.
        Int :$inclusive,               #= Include messages with latest or oldest timestamp in results.
        Timestamp :$latest = now,      #= End of time range of messages to include in results.
        Timestamp :$oldest = 0,        #= Start of time range of messages to include in results.
        Int :$unreads,                 #= Include `unread_count_display` in the output?
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_ts_latest("Value passed for `latest` was invalid"), :invalid_ts_oldest("Value passed for `oldest` was invalid")};
        $.api.request('im.history', :%errors, :$channel, :$count, :$inclusive, :$latest, :$oldest, :$unreads, |%args);
    }


    #| Lists direct message channels for the calling user.
    method list(IM:D: 
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('im.list', :%errors, |%args);
    }


    #| Sets the read cursor in a direct message channel.
    method mark(IM:D: 
        SlackDirect :$channel!,        #= Direct message channel to set reading cursor in.
        Timestamp :$ts!,               #= Timestamp of the most recently seen message.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_timestamp("Value passed for `timestamp` was invalid."), :not_in_channel("Caller is not a member of the channel.")};
        $.api.request('im.mark', :%errors, :$channel, :$ts, |%args);
    }


    #| Opens a direct message channel.
    method open(IM:D: 
        SlackUser :$user!,             #= User to open a direct message channel with.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:user_disabled("The `user` has been disabled."), :user_not_found("Value passed for `user` was invalid."), :user_not_visible("The calling user is restricted from seeing the requested user.")};
        $.api.request('im.open', :%errors, :$user, |%args);
    }


}

#| Accessor for im object
method im(::?CLASS:D:) returns IM:D {
    state $object = IM.new(api => self);
    $object;
}

class MPIM is Base {
    #| Closes a multiparty direct message channel.
    method close(MPIM:D: 
        SlackGroup :$channel!,         #= MPIM to close.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid.")};
        $.api.request('mpim.close', :%errors, :$channel, |%args);
    }


    #| Fetches history of messages and events from a multiparty direct message.
    method history(MPIM:D: 
        SlackGroup :$channel!,         #= Multiparty direct message to fetch history for.
        Int :$count = 100,             #= Number of messages to return, between 1 and 1000.
        Int :$inclusive,               #= Include messages with latest or oldest timestamp in results.
        Timestamp :$latest = now,      #= End of time range of messages to include in results.
        Timestamp :$oldest = 0,        #= Start of time range of messages to include in results.
        Int :$unreads,                 #= Include `unread_count_display` in the output?
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_ts_latest("Value passed for `latest` was invalid"), :invalid_ts_oldest("Value passed for `oldest` was invalid")};
        $.api.request('mpim.history', :%errors, :$channel, :$count, :$inclusive, :$latest, :$oldest, :$unreads, |%args);
    }


    #| Lists multiparty direct message channels for the calling user.
    method list(MPIM:D: 
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('mpim.list', :%errors, |%args);
    }


    #| Sets the read cursor in a multiparty direct message channel.
    method mark(MPIM:D: 
        SlackGroup :$channel!,         #= multiparty direct message channel to set reading cursor in.
        Timestamp :$ts!,               #= Timestamp of the most recently seen message.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid."), :invalid_timestamp("Value passed for `timestamp` was invalid.")};
        $.api.request('mpim.mark', :%errors, :$channel, :$ts, |%args);
    }


    #| This method opens a multiparty direct message.
    method open(MPIM:D: 
        SlackUser :@users!,            #= Comma separated lists of users.  The ordering of the users is preserved whenever a MPIM group is returned.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:not_enough_users("Needs at least 2 users to open"), :too_many_users("Needs at most 8 users to open"), :users_list_not_supplied("Missing `users` in request")};
        $.api.request('mpim.open', :%errors, :@users, |%args);
    }


}

#| Accessor for mpim object
method mpim(::?CLASS:D:) returns MPIM:D {
    state $object = MPIM.new(api => self);
    $object;
}

class OAuth is Base {
    #| Exchanges a temporary OAuth code for an API token.
    method access(OAuth: 
        :$client-id!,                  #= Issued when you created your application.
        :$client-secret!,              #= Issued when you created your application.
        :$code!,                       #= The `code` param returned via the OAuth callback.
        :$redirect-uri,                #= This must match the originally submitted URI (if one was sent).
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:bad_client_secret("Value passed for `client_secret` was invalid."), :bad_redirect_uri("Value passed for `redirect_uri` did not match the `redirect_uri` in the original request."), :invalid_client_id("Value passed for `client_id` was invalid."), :invalid_code("Value passed for `code` was invalid.")};
        $.api.request('oauth.access', :%errors, :$client-id, :$client-secret, :$code, :$redirect-uri, |%args);
    }


}

#| Accessor for oauth object
method oauth(::?CLASS:) returns OAuth {
    dd self.WHAT;
    state $object = OAuth.new(api => self.WHAT);
    $object;
}

class Pins is Base {
    #| Pins an item to a channel.
    method add(Pins:D: 
        SlackChannel :$channel!,       #= Channel to pin the item in.
        Str :$file,                    #= File to pin.
        Str :$file-comment,            #= File comment to pin.
        Timestamp :$timestamp,         #= Timestamp of the message to pin.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:already_pinned("The specified item is already pinned to the channel."), :bad_timestamp("Value passed for `timestamp` was invalid."), :channel_not_found("The `channel` argument was not specified or was invalid"), :file_comment_not_found("File comment specified by `file_comment` does not exist."), :file_not_found("File specified by `file` does not exist."), :file_not_shared("File specified by `file` is not public nor shared to the channel."), :message_not_found("Message specified by `channel` and `timestamp` does not exist."), :no_item_specified("One of `file`, `file_comment`, or `timestamp` was not specified."), :permission_denied("The user does not have permission to add pins to the channel.")};
        $.api.request('pins.add', :%errors, :$channel, :$file, :$file-comment, :$timestamp, |%args);
    }


    #| Lists items pinned to a channel.
    method list(Pins:D: 
        SlackChannel :$channel!,       #= Channel to get pinned items for.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:channel_not_found("Value passed for `channel` was invalid.")};
        $.api.request('pins.list', :%errors, :$channel, |%args);
    }


    #| Un-pins an item from a channel.
    method remove(Pins:D: 
        SlackChannel :$channel!,       #= Channel where the item is pinned to.
        Str :$file,                    #= File to un-pin.
        Str :$file-comment,            #= File comment to un-pin.
        Timestamp :$timestamp,         #= Timestamp of the message to un-pin.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:bad_timestamp("Value passed for `timestamp` was invalid."), :file_comment_not_found("File comment specified by `file_comment` does not exist."), :file_not_found("File specified by `file` does not exist."), :message_not_found("Message specified by `channel` and `timestamp` does not exist."), :no_item_specified("One of `file`, `file_comment`, or `timestamp` was not specified."), :not_pinned("The specified item is not pinned to the channel."), :permission_denied("The user does not have permission to remove pins from the channel.")};
        $.api.request('pins.remove', :%errors, :$channel, :$file, :$file-comment, :$timestamp, |%args);
    }


}

#| Accessor for pins object
method pins(::?CLASS:D:) returns Pins:D {
    state $object = Pins.new(api => self);
    $object;
}

class Presence is Base {
    #| Manually set user presence
    method set(Presence:D: 
        :$presence!,                   #= Either `active` or `away`
        *%args,                        #= Any other arguments we don't know about.
    ) is DEPRECATED {
        my %errors := {:invalid_presence("Value passed for `presence` was invalid.")};
        $.api.request('presence.set', :%errors, :$presence, |%args);
    }


}

#| Accessor for presence object
method presence(::?CLASS:D:) returns Presence:D {
    state $object = Presence.new(api => self);
    $object;
}

class Reactions is Base {
    #| Adds a reaction to an item.
    method add(Reactions:D: 
        SlackChannel :$channel,        #= Channel where the message to add reaction to was posted.
        Str :$file,                    #= File to add reaction to.
        Str :$file-comment,            #= File comment to add reaction to.
        :$name!,                       #= Reaction (emoji) name.
        Timestamp :$timestamp,         #= Timestamp of the message to add reaction to.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:already_reacted("The specified item already has the user/reaction combination."), :bad_timestamp("Value passed for `timestamp` was invalid."), :file_comment_not_found("File comment specified by `file_comment` does not exist."), :file_not_found("File specified by `file` does not exist."), :invalid_name("Value passed for `name` was invalid."), :message_not_found("Message specified by `channel` and `timestamp` does not exist."), :no_item_specified("`file`, `file_comment`, or combination of `channel` and `timestamp` was not specified."), :too_many_emoji("The limit for distinct reactions (i.e emoji) on the item has been reached."), :too_many_reactions("The limit for reactions a person may add to the item has been reached.")};
        $.api.request('reactions.add', :%errors, :$channel, :$file, :$file-comment, :$name, :$timestamp, |%args);
    }


    #| Gets reactions for an item.
    method get(Reactions:D: 
        SlackChannel :$channel,        #= Channel where the message to get reactions for was posted.
        Str :$file,                    #= File to get reactions for.
        Str :$file-comment,            #= File comment to get reactions for.
        :$full,                        #= If true always return the complete reaction list.
        Timestamp :$timestamp,         #= Timestamp of the message to get reactions for.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:bad_timestamp("Value passed for `timestamp` was invalid."), :file_comment_not_found("File comment specified by `file_comment` does not exist."), :file_not_found("File specified by `file` does not exist."), :message_not_found("Message specified by `channel` and `timestamp` does not exist."), :no_item_specified("`file`, `file_comment`, or combination of `channel` and `timestamp` was not specified.")};
        $.api.request('reactions.get', :%errors, :$channel, :$file, :$file-comment, :$full, :$timestamp, |%args);
    }


    #| Lists reactions made by a user.
    method list(Reactions:D: 
        UInt :$count = 100,            #= Number of items to return per page.
        :$full,                        #= If true always return the complete reaction list.
        UInt :$page = 1,               #= Page number of results to return.
        SlackUser :$user,              #= Show reactions made by this user. Defaults to the authed user.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:user_not_found("Value passed for `user` was invalid.")};
        $.api.request('reactions.list', :%errors, :$count, :$full, :$page, :$user, |%args);
    }


    #| Removes a reaction from an item.
    method remove(Reactions:D: 
        SlackChannel :$channel,        #= Channel where the message to remove reaction from was posted.
        Str :$file,                    #= File to remove reaction from.
        Str :$file-comment,            #= File comment to remove reaction from.
        :$name!,                       #= Reaction (emoji) name.
        Timestamp :$timestamp,         #= Timestamp of the message to remove reaction from.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:bad_timestamp("Value passed for `timestamp` was invalid."), :file_comment_not_found("File comment specified by `file_comment` does not exist."), :file_not_found("File specified by `file` does not exist."), :invalid_name("Value passed for `name` was invalid."), :message_not_found("Message specified by `channel` and `timestamp` does not exist."), :no_item_specified("`file`, `file_comment`, or combination of `channel` and `timestamp` was not specified."), :no_reaction("The specified item does not have the user/reaction combination.")};
        $.api.request('reactions.remove', :%errors, :$channel, :$file, :$file-comment, :$name, :$timestamp, |%args);
    }


}

#| Accessor for reactions object
method reactions(::?CLASS:D:) returns Reactions:D {
    state $object = Reactions.new(api => self);
    $object;
}

class RTM is Base {
    #| Starts a Real Time Messaging session.
    method start(RTM:D: 
        Bool :$mpim-aware,             #= Returns MPIMs to the client in the API response.
        Int :$no-unreads,              #= Skip unread counts for each channel (improves performance).
        Int :$simple-latest,           #= Return timestamp only for latest message object of each channel (improves performance).
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:migration_in_progress("Team is being migrated between servers. See [the `team_migration_started` event documentation](/events/team_migration_started) for details.")};
        $.api.request('rtm.start', :%errors, :$mpim-aware, :$no-unreads, :$simple-latest, |%args);
    }


}

#| Accessor for rtm object
method rtm(::?CLASS:D:) returns RTM:D {
    state $object = RTM.new(api => self);
    $object;
}

class Search is Base {
    #| Searches for messages and files matching a query.
    method all(Search:D: 
        UInt :$count,                  #= Number of items to return per page.
        :$highlight,                   #= Pass a value of `1` to enable query highlight markers (see below).
        UInt :$page = 1,               #= Page number of results to return.
        :$query!,                      #= Search query. May contains booleans, etc.
        Str :$sort = 'score',          #= Return matches sorted by either `score` or `timestamp`.
        Str :$sort-dir = 'desc',       #= Change sort direction to ascending (`asc`) or descending (`desc`).
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('search.all', :%errors, :$count, :$highlight, :$page, :$query, :$sort, :$sort-dir, |%args);
    }


    #| Searches for files matching a query.
    method files(Search:D: 
        UInt :$count,                  #= Number of items to return per page.
        :$highlight,                   #= Pass a value of `1` to enable query highlight markers (see below).
        UInt :$page = 1,               #= Page number of results to return.
        :$query!,                      #= Search query. May contain booleans, etc.
        Str :$sort = 'score',          #= Return matches sorted by either `score` or `timestamp`.
        Str :$sort-dir = 'desc',       #= Change sort direction to ascending (`asc`) or descending (`desc`).
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('search.files', :%errors, :$count, :$highlight, :$page, :$query, :$sort, :$sort-dir, |%args);
    }


    #| Searches for messages matching a query.
    method messages(Search:D: 
        UInt :$count,                  #= Number of items to return per page.
        :$highlight,                   #= Pass a value of `1` to enable query highlight markers (see below).
        UInt :$page = 1,               #= Page number of results to return.
        :$query!,                      #= Search query. May contains booleans, etc.
        Str :$sort = 'score',          #= Return matches sorted by either `score` or `timestamp`.
        Str :$sort-dir = 'desc',       #= Change sort direction to ascending (`asc`) or descending (`desc`).
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('search.messages', :%errors, :$count, :$highlight, :$page, :$query, :$sort, :$sort-dir, |%args);
    }


}

#| Accessor for search object
method search(::?CLASS:D:) returns Search:D {
    state $object = Search.new(api => self);
    $object;
}

class Stars is Base {
    #| Adds a star to an item.
    method add(Stars:D: 
        SlackChannel :$channel,        #= Channel to add star to, or channel where the message to add star to was posted (used with `timestamp`).
        Str :$file,                    #= File to add star to.
        Str :$file-comment,            #= File comment to add star to.
        Timestamp :$timestamp,         #= Timestamp of the message to add star to.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:already_starred("The specified item has already been starred by the authenticated user."), :bad_timestamp("Value passed for `timestamp` was invalid."), :channel_not_found("Channel, private group, or DM specified by `channel` does not exist"), :file_comment_not_found("File comment specified by `file_comment` does not exist."), :file_not_found("File specified by `file` does not exist."), :message_not_found("Message specified by `channel` and `timestamp` does not exist."), :no_item_specified("`file`, `file_comment`, `channel` and `timestamp` was not specified.")};
        $.api.request('stars.add', :%errors, :$channel, :$file, :$file-comment, :$timestamp, |%args);
    }


    #| Lists stars for a user.
    method list(Stars:D: 
        UInt :$count = 100,            #= Number of items to return per page.
        UInt :$page = 1,               #= Page number of results to return.
        SlackUser :$user,              #= Show stars by this user. Defaults to the authed user.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:user_not_found("Value passed for `user` was invalid")};
        $.api.request('stars.list', :%errors, :$count, :$page, :$user, |%args);
    }


    #| Removes a star from an item.
    method remove(Stars:D: 
        SlackChannel :$channel,        #= Channel to remove star from, or channel where the message to remove star from was posted (used with `timestamp`).
        Str :$file,                    #= File to remove star from.
        Str :$file-comment,            #= File comment to remove star from.
        Timestamp :$timestamp,         #= Timestamp of the message to remove star from.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:bad_timestamp("Value passed for `timestamp` was invalid."), :channel_not_found("Channel, private group, or DM specified by `channel` does not exist"), :file_comment_not_found("File comment specified by `file_comment` does not exist."), :file_not_found("File specified by `file` does not exist."), :message_not_found("Message specified by `channel` and `timestamp` does not exist."), :no_item_specified("`file`, `file_comment`, `channel` and `timestamp` was not specified."), :not_starred("The specified item is not currently starred by the authenticated user.")};
        $.api.request('stars.remove', :%errors, :$channel, :$file, :$file-comment, :$timestamp, |%args);
    }


}

#| Accessor for stars object
method stars(::?CLASS:D:) returns Stars:D {
    state $object = Stars.new(api => self);
    $object;
}

class Team is Base {
    #| Gets the access logs for the current team.
    method access-logs(Team:D: 
        UInt :$count = 100,            #= Number of items to return per page.
        UInt :$page = 1,               #= Page number of results to return.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:over_pagination_limit("It is not possible to request more than 1000 items per page or more than 100 pages."), :paid_only("This is only available to paid teams.")};
        $.api.request('team.accessLogs', :%errors, :$count, :$page, |%args);
    }


    #| Gets information about the current team.
    method info(Team:D: 
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('team.info', :%errors, |%args);
    }


    #| Gets the integration logs for the current team.
    method integration-logs(Team:D: 
        Int :$app-id,                  #= Filter logs to this Slack app. Defaults to all logs.
        :$change-type,                 #= Filter logs with this change type. Defaults to all logs.
        UInt :$count = 100,            #= Number of items to return per page.
        UInt :$page = 1,               #= Page number of results to return.
        Int :$service-id,              #= Filter logs to this service. Defaults to all logs.
        SlackUser :$user,              #= Filter logs generated by this user’s actions. Defaults to all logs.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('team.integrationLogs', :%errors, :$app-id, :$change-type, :$count, :$page, :$service-id, :$user, |%args);
    }


}

#| Accessor for team object
method team(::?CLASS:D:) returns Team:D {
    state $object = Team.new(api => self);
    $object;
}

class UserGroups is Base {
    #| Create a user group
    method create(UserGroups:D: 
        Str :$channels,                #= A comma separated string of encoded channel IDs for which the user group uses as a default.
        Str :$description,             #= A short description of the user group.
        Str :$handle,                  #= A mention handle. Must be unique among channels, users and user groups.
        Int :$include-count,           #= Include the number of users in each user group.
        Str :$name!,                   #= A name for the user group. Must be unique among user groups.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('usergroups.create', :%errors, :$channels, :$description, :$handle, :$include-count, :$name, |%args);
    }


    #| Disable an existing user group
    method disable(UserGroups:D: 
        Int :$include-count,           #= Include the number of users in the user group.
        Str :$usergroup!,              #= The encoded ID of the user group to disable.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('usergroups.disable', :%errors, :$include-count, :$usergroup, |%args);
    }


    #| Enable a user group
    method enable(UserGroups:D: 
        Int :$include-count,           #= Include the number of users in the user group.
        Str :$usergroup!,              #= The encoded ID of the user group to enable.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('usergroups.enable', :%errors, :$include-count, :$usergroup, |%args);
    }


    #| List all user groups for a team
    method list(UserGroups:D: 
        Int :$include-count,           #= Include the number of users in each user group.
        Int :$include-disabled,        #= Include disabled user groups.
        Int :$include-users,           #= Include the list of users for each user group.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('usergroups.list', :%errors, :$include-count, :$include-disabled, :$include-users, |%args);
    }


    #| Update an existing user group
    method update(UserGroups:D: 
        Str :$channels,                #= A comma separated string of encoded channel IDs for which the user group uses as a default.
        Str :$description,             #= A short description of the user group.
        Str :$handle,                  #= A mention handle. Must be unique among channels, users and user groups.
        Int :$include-count,           #= Include the number of users in the user group.
        Str :$name,                    #= A name for the user group. Must be unique among user groups.
        Str :$usergroup!,              #= The encoded ID of the user group to update.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('usergroups.update', :%errors, :$channels, :$description, :$handle, :$include-count, :$name, :$usergroup, |%args);
    }


    #| Access the nested users object
    method users(UserGroups:D:) {
        state $nested = UserGroups::Users.new(:$.api);
        $nested
    }

}

#| Accessor for usergroups object
method usergroups(::?CLASS:D:) returns UserGroups:D {
    state $object = UserGroups.new(api => self);
    $object;
}

class UserGroups::Users is Base {
    #| List all users in a user group
    method list(UserGroups::Users:D: 
        Int :$include-disabled,        #= Allow results that involve disabled user groups.
        Str :$usergroup!,              #= The encoded ID of the user group to update.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('usergroups.users.list', :%errors, :$include-disabled, :$usergroup, |%args);
    }


    #| Update the list of users for a user group
    method update(UserGroups::Users:D: 
        Int :$include-count,           #= Include the number of users in the user group.
        Str :$usergroup!,              #= The encoded ID of the user group to update.
        Str :$users!,                  #= A comma separated string of encoded user IDs that represent the entire list of users for the user group.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('usergroups.users.update', :%errors, :$include-count, :$usergroup, :$users, |%args);
    }


}

class Users is Base {
    #| Gets user presence information.
    method get-presence(Users:D: 
        SlackUser :$user!,             #= User to get presence info on. Defaults to the authed user.
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('users.getPresence', :%errors, :$user, |%args);
    }


    #| Gets information about a user.
    method info(Users:D: 
        SlackUser :$user!,             #= User to get info on
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:user_not_found("Value passed for `user` was invalid."), :user_not_visible("The requested user is not visible to the calling user")};
        $.api.request('users.info', :%errors, :$user, |%args);
    }


    #| Lists all users in a Slack team.
    method list(Users:D: 
        :$presence,                    #= Whether to include presence data in the output
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('users.list', :%errors, :$presence, |%args);
    }


    #| Marks a user as active.
    method set-active(Users:D: 
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := %;
        $.api.request('users.setActive', :%errors, |%args);
    }


    #| Manually sets user presence.
    method set-presence(Users:D: 
        :$presence!,                   #= Either `auto` or `away`
        *%args,                        #= Any other arguments we don't know about.
    ) {
        my %errors := {:invalid_presence("Value passed for `presence` was invalid.")};
        $.api.request('users.setPresence', :%errors, :$presence, |%args);
    }


}

#| Accessor for users object
method users(::?CLASS:D:) returns Users:D {
    state $object = Users.new(api => self);
    $object;
}

