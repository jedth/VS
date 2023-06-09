-module(ko_send).

-export([msg/1]).

-import(vsutil, [get_config_value/2]).

msg(Command) ->
    {ok, KoordinatorConfig} = file:consult("koordinator.cfg"),

    {ok, NameServiceNode} = get_config_value(nameservicenode, KoordinatorConfig),
    {ok, KoordinatorName} = get_config_value(koordinatorname, KoordinatorConfig),

    Koordinator =
        case net_adm:ping(NameServiceNode) of
            pang ->
                io:format("nameservice konnte nicht gefunden werden~n", []),
                ok;
            pong ->
                NameService = {nameservice, NameServiceNode},
                nameservice_lookup(NameService, KoordinatorName)
        end,

    case Command of
        help ->
            io:format(
                unicode:characters_to_list(
                    "Avaliable Commands:~n"
                    "    help:        Liste aller commands,~n"
                    "    vals:        Steuerungswerte,~n"
                    "    ggt:         Zufalls ggT,~n"
                    "    {calc,Wggt}: Berechnung des ggT mit einem Wunschggt starten,~n"
                    "    step:        Beendet Anmeldephase,~n"
                    "    nudge:       eine Art ping,~n"
                    "    prompt:      aktuelle Mi's anzeigen,~n"
                    "    toggle:      Korrektur-Flag aendern,~n"
                    "    toggle_ggt:  Korrektur-Flags der GGTs aendern,~n"
                    "    reset:       Koordinator in Initial-Zustand versetzen und Berechnung abbrechen,~n"
                    "    kill:        alle Prozesse (bis auf Namensdienst) beenden.~n"
                )
            );
        vals ->
            Koordinator ! {self(), getsteeringval},
            receive
                {steeringval, Arbeitszeit, TermZeit, Anzahl} ->
                    io:format(
                        "Steuerungswerte:~n"
                        "   Arbeitszeit: ~p~n"
                        "   Terminierungszeit: ~B~n"
                        "   Anzahl ggT-Prozesse: ~B~n",
                        [Arbeitszeit, TermZeit, Anzahl]
                    )
            after 3000 ->
                io:fwrite("Keine Antwort erhalten.~n")
            end;
        ggt ->
            Koordinator ! ggt;
        {calc, Wggt} ->
            Koordinator ! {calc, Wggt};
        step ->
            Koordinator ! step;
        nudge ->
            Koordinator ! nudge;
        prompt ->
            Koordinator ! prompt;
        toggle ->
            Koordinator ! toggle;
        toggle_ggt ->
            Koordinator ! toggle_ggt;
        reset ->
            Koordinator ! reset;
        kill ->
            Koordinator ! kill;
        _ ->
            io:fwrite("unknown command, try help instead.")
    end,
    ok.

nameservice_lookup(NameService, Service) ->
    NameService ! {self(), {lookup, Service}},
    receive
        not_found ->
            not_found;
        {pin, {Name, Node}} ->
            {Name, Node}
    end.
