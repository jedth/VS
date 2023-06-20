-module(vectorC).

-export([initVT/0]).
-export([myVTid/1]).
-export([myVTvc/1]).
-export([myCount/1]).
-export([foCount/2]).
-export([isVT/1]).
-export([syncVT/2]).
-export([tickVT/1]).
-export([compVT/2]).

-include_lib("eunit/include/eunit.hrl").

-import(vsutil, [get_config_value/2, now2string/1]).
-import(util, [logging/2]).
-import(io_lib, [format/2]).
-import(io, [format/1]).

-define(DELAY, 3000).

initVT() ->
    {ok, HostName} = inet:gethostname(),
    LogFile = format("VectorC@~s.log", [HostName]),

    %% 4.1 Auslesen von servername und servernode aus der Konfigureationsdatei
    TowerClockConfig =
        case file:consult("towerClock.cfg") of
            {ok, File} ->
                File;
            {error, Reason} ->
                io:format("~nProblem mit towerClock.cfg: ~s~n", [Reason]),
                exit(bad_config)
        end,
    {ok, ServerName} = get_config_value(servername, TowerClockConfig),
    {ok, ServerNode} = get_config_value(servernode, TowerClockConfig),

    %% 4.2 Kontaktaufbau zur towerClock
    {ok, TowerClockPID} =
        case net_adm:ping(ServerNode) of
            pang ->
                ErrReason = format("towerClock konnte nicht gefunden werden~n", []),
                logging(LogFile, ErrReason),
                {error, ErrReason};
            pong ->
                {ServerName, ServerNode} ! {getVecID, self()},
                receive
                    Anwser ->
                        {ok, Anwser}
                after ?DELAY ->
                    TimeOutErr = format("keine Antwort von towerClock erhalten"),
                    logging(LogFile, TimeOutErr),
                    {error, TimeOutErr}
                end
        end,
    register(ServerName, TowerClockPID),

    %% 4.3
    TowerClockPID ! {getVecID, self()},
    VecPID =
        receive
            {vt, ProzessID} ->
                ProzessID
        after ?DELAY ->
            TimeOutPID = format("keine Antwort von towerClock erhalten"),
            logging(LogFile, TimeOutPID),
            {error, TimeOutPID}
        end,
    %% TODO muss das hier wirklich die länge von VecPID haben?
    %% 4.4 & 4.5
    {VecPID, []}.

%% @doc ermittelt die eindeutige ID der Kommunikationseinheit
myVTid({ID, _List}) ->
    %% 5.1
    ID.

%% @doc ermittelt den Vektor eines Vektorzeitstempels
myVTvc({_ID, List}) ->
    %% 6.1
    List.

%% @doc ermittelt den Zaehlerwert zur eigenen ID aus einem Vektorzeitstempel
myCount({ID, Vec}) ->
    %%   ^ 7.1
    %% 7.2, 7.3
    lists_nth(ID, Vec).

myCount_test() ->
    TestList = [1, 2, 3, 4, 5, 6, 7],
    ?assertEqual(1, myCount({1, TestList})),
    ?assertEqual(7, myCount({7, TestList})),
    ok.

foCount(J, {_, Vec}) ->
    %%   ^ 8.1
    %% 8.2, 8.3
    lists_nth(J, Vec).

-type vectorTimestamp() :: {pos_integer(), [pos_integer(), ...]}.

%% @doc ueberprueft das Format eines Vektorzeitstempels
-spec isVT(VT) -> true | false when VT :: vectorTimestamp().
isVT({ID, Vec = [Elem | _]}) when is_integer(ID), length(Vec) =:= ID, is_integer(Elem) ->
    %% ^ 9.1, 9.2                      ^ 9.3             ^ 9.4          ^ 9.5
    %% 9.6
    true;
isVT(_Any) ->
    false.

syncVT({ID, Vec1}, {_, Vec2}) ->
    %%         ^ 10.1
    %% 10.2
    {Vector1Ext, Vector2Ext} = extendVector(Vec1, Vec2),
    %% 10.3, 10.4
    VectorNeu = zip_vt(Vector1Ext, Vector2Ext),
    %% 10.5, 10.6
    {ID, VectorNeu}.

zip_vt(Vec, Vec2) ->
    lists_reverse(zip_vt_internal(Vec, Vec2, [])).

zip_vt_internal([], [], Acc) ->
    Acc;
zip_vt_internal([H | Tail], [H2 | Tail2], Acc) when H >= H2 ->
    zip_vt_internal(Tail, Tail2, [H | Acc]);
zip_vt_internal([H | Tail], [H2 | Tail2], Acc) when H < H2 ->
    zip_vt_internal(Tail, Tail2, [H2 | Acc]).

zip_vt_test() ->
    TestList = [1, 2, 3, 4, 5, 10, 7],
    TestList2 = [1, 9, 3, 9, 5, 6, 7],
    Outcome = [1, 9, 3, 9, 5, 10, 7],
    ?assertEqual(Outcome, zip_vt(TestList, TestList2)),
    todo.

syncVT_test() ->
    todo.

%% (14.)
extendVector(_, _) ->
    todo.

extendVector_test() ->
    todo.

tickVT({ID, Vec}) ->
    %%  ^ 11.1
    %% 11.2, 11.3, 11.4, 11.5
    {ID, tickVT_internal(ID, Vec)}.

tickVT_internal(1, [Elem | Tail]) ->
    [Elem + 1 | Tail];
tickVT_internal(ID, [H | T]) ->
    [H | tickVT_internal(ID - 1, T)].

tickVT_internal_test() ->
    TestList = [1, 2, 3, 4, 5, 6, 7],
    ModifiedList = [1, 2, 3, 4, 5, 6, 8],
    ModifiedList2 = [1, 2, 3, 5, 5, 6, 7],
    ?assertEqual(ModifiedList, tickVT_internal(7, TestList)),
    ?assertEqual(ModifiedList2, tickVT_internal(4, TestList)),
    ok.

%% (12.)
compVT({_, Vec}, {_, Vec2}) ->
    %%       ^ 12.1
    %% 12.2
    {Vektor1Ext, Vektor2Ext} = extendVector(Vec, Vec2),
    %% 12.3
    compareVector(Vektor1Ext, Vektor2Ext).

%% (13.)
aftereqVTJ(VT, VTR) ->
    todo.

%% Hilfsfunktionen %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 15.
compareVector([Elem | Tail], [Elem2 | Tail2]) ->
    case compareElem(Elem, Elem2) of
        beforeVT ->
            compareVectorLast(Tail, Tail2, beforeVT);
        equalVT ->
            compareVectorLast(Tail, Tail2, equalVT);
        afterVT ->
            compareVectorLast(Tail, Tail2, afterVT)
    end.

%% Last :: beforeVT|equalVT|afterVT
compareVectorLast([], [], Last) ->
    Last;
compareVectorLast([Elem | Tail], [Elem2 | Tail2], Last) ->
    case compareElem(Elem, Elem2) == Last of
        true ->
            compareVectorLast(Tail, Tail2, Last);
        false ->
            concurrentVT
    end.

compareElem(Elem, Elem2) ->
    if Elem =< Elem2 ->
           beforeVT;
       Elem =:= Elem2 ->
           equalVT;
       Elem >= Elem2 ->
           afterVT
    end.

compareVector_test() ->
    TestList = [1, 2, 3, 4, 5, 6, 7],
    TestList2 = [1, 2, 3, 4, 5, 6, 7],
    ?assertEqual(equalVT, compareVector(TestList, TestList2)),
    todo.

%% util %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% generelle Hilfsfunktionen (nicht im Entwurf dokumentiert)

-spec lists_nth(N, List) -> Elem
    when N :: pos_integer(),
         List :: [T, ...],
         Elem :: T | [],
         T :: term().
lists_nth(_Num, []) ->
    [];
lists_nth(1, [H | _]) ->
    H;
lists_nth(N, [_ | T]) when N > 1 ->
    lists_nth(N - 1, T).

lists_nth_test() ->
    TestList = [1, 2, 3, 4, 5, 6, 7],
    ?assertEqual(3, lists_nth(3, TestList)),
    ?assertEqual(1, lists_nth(1, [1])),
    ok.

%% @doc reverses a list.
lists_reverse(List) ->
    lists_reverse(List, []).

lists_reverse([], Accu) ->
    Accu;
lists_reverse([Elem | Tail], Accu) ->
    lists_reverse(Tail, [Elem | Accu]).

lists_reverse_test() ->
    TestList = [1, 2, 3, 4, 5, 6, 7],
    Outcome = [7, 6, 5, 4, 3, 2, 1],
    ?assertEqual(Outcome, lists_reverse(TestList)),
    ?assertEqual([], lists_reverse([])),
    todo.
