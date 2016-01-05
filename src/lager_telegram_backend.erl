-module(lager_telegram_backend).
-behaviour(gen_event).

-include_lib("lager/include/lager.hrl").

%% gen_event callbacks
-export([init/1, handle_call/2, handle_event/2, handle_info/2, terminate/2,
        code_change/3]).

-export([log/3]).

-define(TELEGRAM_BASE_URL, "https://api.telegram.org/bot").

-define(TIMEOUT, 5000).
-define(RETRY_CODES, [429, 500, 502, 503, 504]).

-define(RETRY_TIMES, 3).
-define(RETRY_INTERVAL, 5).

-record(state, {level          :: integer(),
                url            :: string(),
                chat_id        :: pos_integer(),
                retry_times    :: non_neg_integer(),
                retry_interval :: non_neg_integer()}).

init(Args) ->
    Level         = proplists:get_value(level, Args),
    Token         = proplists:get_value(token, Args),
    ChatId        = proplists:get_value(chat_id, Args),
    RetryTimes    = proplists:get_value(retry_times, Args, ?RETRY_TIMES),
    RetryInterval = proplists:get_value(retry_interval, Args, ?RETRY_INTERVAL),
    {ok, #state{level=lager_util:level_to_num(Level),
                url=make_url(Token),
                chat_id=ChatId,
                retry_times=RetryTimes,
                retry_interval=RetryInterval * 1000}}.

handle_call({set_loglevel, Level}, State) ->
    {ok, ok, State#state{level=lager_util:level_to_num(Level)}};
handle_call(get_loglevel, #state{level=Level}=State) ->
    {ok, Level, State};
handle_call(_Request, State) ->
    {ok, ok, State}.

handle_event({log, Message}, #state{level=Level,
                                    url=Url,
                                    chat_id=ChatId,
                                    retry_times=RetryTimes,
                                    retry_interval=RetryInterval}=State) ->
    case lager_util:is_loggable(Message, Level, ?MODULE) of
        true  ->
            RawMessage = lager_msg:message(Message),
            Data = [{"chat_id", ChatId},
                    {"text", lists:flatten(RawMessage)}],
            Request = {Url, [], "application/x-www-form-urlencoded",
                       encode_url(Data)},
            spawn(?MODULE, log, [Request, RetryTimes, RetryInterval]);
        false -> ok
    end,
    {ok, State};
handle_event(_Event, State) ->
    {ok, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%% Internal

make_url(Token) ->
    lists:flatten(
      io_lib:format("~s~s/sendMessage", [?TELEGRAM_BASE_URL, Token])).

log(_Request, 0, _RetryInterval) -> ok;
log(Request, RetryTimes, RetryInterval) ->
    Result = request(Request),
    case need_retry(Result) of
        true  ->
            timer:sleep(RetryInterval),
            log(Request, RetryTimes-1, RetryInterval);
        false -> ok
    end.

need_retry({ok, {Code, _}}) -> lists:member(Code, ?RETRY_CODES);
need_retry(_)               -> true.

encode_url(Data) ->
    encode_url(Data, []).

encode_url([], Acc) ->
    string:join(Acc, "&");
encode_url([{K, V} | Tail], Acc) ->
    encode_url(Tail, [K ++ "=" ++ edoc_lib:escape_uri(to_list(V)) | Acc]).

request(Request) ->
    httpc:request(post, Request,
                  [{timeout, ?TIMEOUT},
                   {autoredirect, false}],
                  [{full_result, false},
                   {body_format, binary}]).

to_list(I) when is_integer(I) -> integer_to_list(I);
to_list(B) when is_binary(B)  -> binary_to_list(B);
to_list(L) when is_list(L)    -> L.
