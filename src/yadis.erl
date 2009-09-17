%%%-------------------------------------------------------------------
%%% File    : yadis.erl
%%% Author  : Brendon Hogger <brendonh@dev.brendonh.org>
%%% Description : Yadis resource discovery
%%%
%%% Created : 17 Sep 2009 by Brendon Hogger <brendonh@dev.brendonh.org>
%%%-------------------------------------------------------------------
-module(yadis).

-export([retrieve/1, test/0]).

-include("openid.hrl").


retrieve(YadisURL) ->
    application:start(inets),
    application:start(ssl),
    
    case http:request(get, {YadisURL, [{"accept", "application/xrds+xml"},
                                       {"connection", "Close"}]},
                      [], []) of
        {ok, {_Status, Headers, Body}} ->
            DescriptorURL = get_descriptor_url(Headers, Body),
            ?DBG({descriptor_url, DescriptorURL});
        Other ->
            ?DBG({error, Other})
    end,
    ok.
    
get_descriptor_url(Headers, Body) when is_list(Headers) ->
    case ?GVD("x-xrds-location", Headers, none) of
        none -> 
            case ?GVD("content-type", Headers, none) of
                "application/xrds+xml" ++ _Rest -> none;
                none -> none;
                _MaybeHTML -> get_descriptor_url(Body)
            end;
        URL -> URL
    end.


get_descriptor_url("<meta" ++ Rest) -> get_meta(Rest);
get_descriptor_url("</head>" ++ _Rest) -> none;
get_descriptor_url("") -> none;
get_descriptor_url([_|Rest]) ->
    get_descriptor_url(Rest).
    

get_meta(Rest) ->
    Content = get_meta_content(Rest, []),
    case re:run(string:to_lower(Content), 
                "([a-z0-9-]+)\s*=\s*[\"'](.*?)[\"']", 
                [{capture, all_but_first, list}, global]) of
        {match, Bits} -> check_meta([{K,V} || [K,V] <- Bits], Rest);
        _ -> get_descriptor_url(Rest)
    end.

check_meta(PropList, Rest) -> 
    case ?GVD("http-equiv", PropList, none) of
        "x-xrds-location" -> ?GVD("content", PropList, none);
        _ -> get_descriptor_url(Rest)
    end.


get_meta_content(">" ++ _Rest, Content) -> lists:reverse(Content);
get_meta_content([Char|Rest], Bits) -> get_meta_content(Rest, [Char|Bits]).
    



test() ->
    retrieve("https://www.google.com/accounts/o8/id"), % Direct XRDS response
    retrieve("https://api.screenname.aol.com/auth/openidServer"), % x-xrds-location header
    retrieve("http://exbrend.livejournal.com"). % x-xrds-location meta tag
    

%% brendonh@dev:~/projects/erl_openid$ make test
%% erlc -o ebin -Wall -v +debug_info src/yadis.erl
%% erl +W w -pa ebin -noshell -s yadis test -s init stop
%% <0.1.0>: {descriptor_url,none}
%% <0.1.0>: {descriptor_url,"http://api.screenname.aol.com/yadis.xml"}
%% <0.1.0>: {descriptor_url,"http://exbrend.livejournal.com/data/yadis"}
