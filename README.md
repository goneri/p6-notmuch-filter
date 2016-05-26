# A script to tag new mail with Notmuch

You can use this script to do the initial tagging of all your new mails.

## Installation

    panda install Email::Notmuch
    panda install Email::Simple
    panda install File::HomeDir
    panda install JSON::Tiny

## Configuration

    cp notmuch-filter.json ~/Maildir
    editor ~/Maildir/notmuch-filter.json

## Run it

    perl6 notmuch-filter.p6
