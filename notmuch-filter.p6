use v6;

use Email::Simple;
use Email::Notmuch;
use File::HomeDir;
use JSON::Tiny;


sub find_messages($filter) {
    my $database = Database.open(File::HomeDir.my-home ~ '/Maildir', 'r');
    "$filter".say;
    my $query = Query.new($database, $filter);
    my $messages = $query.search_messages();

    my @entries;
    for $messages.all() -> $message {
        my $killed = False;
        $query = Query.new($database, 'thread:' ~ $message.get_thread_id());
        my $threads = $query.search_threads();
        for $threads.all() -> $thread {
            if $thread.get_tags().all().grep('killed') {
                $killed = True;
                last;
            }
        }

        @entries.push: {
            filename => $message.get_filename(),
            thread_id => $message.get_thread_id(),
            message_id => $message.get_message_id(),
            tags => $message.get_tags().all(),
            killed => $killed,
        }
    }
    $database.close();

    return @entries
}

sub set_tags($message_id, @tags, @new_tags) {
    my @remove_tags;
    my @add_tags;
#    say "Current " ~ @tags;
    for @new_tags -> $raw_tag {
        for $raw_tag.split(' ') -> $tag_op {
            my $tag = $tag_op.substr(1); # drop the +/-
#            say "Eval: " ~ $tag;
            if $tag_op.starts-with('-') {
                @remove_tags.push: $tag;
                say 'remove tag ' ~ $tag;
            } elsif $tag_op.starts-with('+') {
                @add_tags.push: $tag;
                say 'add tag ' ~ $tag;
            } else {
                say 'Ignore ' ~ $tag;
            }
        }
    }
    if @remove_tags or @add_tags {
        my $database = Database.open(File::HomeDir.my-home ~ '/Maildir', 'w');
        my $message = $database.find_message($message_id);
        for @add_tags -> $tag {
            $message.add_tag($tag);
        }
        for @remove_tags -> $tag {
            $message.remove_tag($tag);
        }
        say "At the end: " ~ $message.get_tags().all();
        $database.close();
    }
}

my $settings = from-json(slurp File::HomeDir.my-home ~ '/Maildir/notmuch-filter.json');

my %to_change;

for %$settings.kv -> $filter, $rules {
    my @entries = find_messages($filter);

    for @entries -> %e {
        my $filename = %e<filename>;
        my $content = "";
        {
            CATCH {
                default {
                    $content = slurp $filename, enc => 'latin1';
                    say 'Switching to latin1 encoding';
                }
            }
            $content = slurp $filename;

        };
        my $email = Email::Simple.new($content);
        my @new_tags;
        for @$rules -> %rule {
            my $re = %rule{'Pattern'};
            if not $re {
                push @new_tags, %rule{'Tags'};
                next;
            }

            my $field = $email.header(%rule{'Field'});
            next unless $field;

            if $field ~~ m :ignorecase/ $re / {
                push @new_tags, %rule{'Tags'};
            }
        }
        if %e<killed> {
            say "Killed!";
            @new_tags.push: '-inbox';
        }
        set_tags(%e<message_id>, %e<tags>, @new_tags);
    }
}
