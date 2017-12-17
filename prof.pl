#!/home/eu/.linuxbrew/bin/swipl

:- set_prolog_flag(verbose, silent).

:- initialization main.

:- use_module(library(persistency)).
:- use_module(library(atom_feed)).

:- persistent
    seen(feed:atom, url:atom).

% USER CONFIGURATION

%feed('chess',  url('https://www.reddit.com/r/chess/new/.rss')).
%feed('prolog', url('https://www.reddit.com/r/prolog/new/.rss')).
feed('ocaml', url('https://www.reddit.com/r/ocaml/new/.rss')).
feed('hackernews', url('https://news.ycombinator.com/rss')).
%feed('schachmatt',
%url('http://www.sc-schachmatt-botnang.schachvereine.de/feed/')).

from_address('prof@eu.avior.uberspace.de').
from_name('Prolog Feeds').
from(From) :-
    from_name(Name),
    from_address(Address),
    format(atom(From), 'From: ~w <~w>', [Name, Address]).

address(Any, 'eu-daniel') :-
    feed(Any, _).

db_file('/home/eu/etc/feeds.db').

% END OF CONFIGURATION

digest(Name, Feed, Digest) :-
    findall(SeenItem, seen(Name, SeenItem), Seen),
    retractall_seen(Name, _),
    findall(entry(Title, Summary, Url), (
        entry(Feed, Article),
        link(Article, Link),
        rel(Link, alternate),
        href(Link, Url),
        assert_seen(Name, Url),
        \+ member(Url, Seen),
        title(Article, Title),
        digest_summary(Article, Summary)), Digest).

digest_summary(Entry, Summary) :-
    summary(Entry, Summary), !.

digest_summary(Entry, Summary) :-
    description(Entry, Summary), !.

digest_summary(Entry, Summary) :-
    content(Entry, Summary), !.

digest_summary(_, 'No description').

write_headers(P, Name, Address) :-
    from(From),
    writeln(P, From),
    format(atom(To), 'To: <~w>', [Address]),
    writeln(P, To),
    format(atom(Subject), 'Subject: digest for ~w', [Name]),
    writeln(P, Subject),
    writeln(P, 'Content-Type: text/html; charset=UTF-8'),
    writeln(P, ''),
    writeln(P, '<html><head><style>pre { white-space: pre-wrap; }</style></head><body>').

write_article(P, entry(Title, Summary, Url)) :-
    write(P, '<h3><a href="'), write(P, Url), write(P, '">'), write(P, Title),
    writeln(P, '</a></h3>'),
    writeln(P, Summary),
    writeln(P, '<hr />').

write_digest(P, Digest) :-
    forall(member(Entry, Digest), write_article(P, Entry)).

main :-
    db_file(DBFile),
    db_attach(DBFile, []),
    forall(feed(Name, Url), ignore((
        address(Name, Address),
        new_feed(Url, Feed),
        digest(Name, Feed, Digest),
        \+ Digest = [] ->
        (
            length(Digest, N),
            format(user_error, '~w: ~w new entries~n', [Name, N]),
            from_address(FromAddress),
            from_name(FromName),
            process_create(path(sendmail),
                           ['-F', FromName,
                            '-f', FromAddress,
                            Address],
                           [stdin(pipe(P))]),
            write_headers(P, Name, Address),
            write_digest(P, Digest),
            writeln(P, '</body></html>'),
            close(P))
        ) ;
        (
            format(user_error, '~w: No new entries~n', [Name])
        ))
    ),
    db_sync(gc),
%	db_detach,
    halt(0).

main :-
    halt(1).
