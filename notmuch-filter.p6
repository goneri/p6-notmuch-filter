use v6;

use Email::Simple;
use Email::Notmuch;
use JSON::Tiny;

my $rules = from-json(slurp 'notmuch-filter.json');

my $database = Database.open('/home/goneri/Maildir', 'w');
my $query = Query.new($database, 'tag:new');
my $messages = $query.search_messages();

for $messages.all() -> $message {
    my $filename = $message.get_filename();
    say '------------';
    say $filename;
    my $content;
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
    my @new_tags = ('-new');
    my %header_cache;
    for @$rules -> %rule {
        my $re = %rule{'Pattern'};
        if not %header_cache<%rule{'Field'}>:exists {
            %header_cache{%rule{'Field'}} = $email.header(%rule{'Field'});
        }
        my $field = %header_cache{%rule{'Field'}};
        next unless $field;

        if $field ~~ m :ignorecase/ $re / {
            push @new_tags, %rule{'Tags'};
        }

    }
    my $query = Query.new($database, 'thread:' ~ $message.get_thread_id());
    my $threads = $query.search_threads();
    for $threads.all() -> $thread {
        if $thread.get_tags().all().grep('killed') {
            @new_tags.append('-inbox');
            last;
        }
    }

    for @new_tags -> $raw_tag {
        for $raw_tag.split(' ') -> $tag_op {
            my $tag = $tag_op.substr(1); # drop the +/-
            if $tag_op.starts-with('-') {
                $message.remove_tag($tag);
                say 'remove tag ' ~ $tag;
            } elsif $raw_tag.starts-with('+') {
                $message.add_tag($tag);
                say 'add tag ' ~ $tag;
            } else {
                say 'Unexpected tag>' ~ $tag_op ~ '<';
            }
        }
    }
}
$database.close();
