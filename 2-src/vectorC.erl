-module(vectorC).

-author("Belal Karimzai").
-export([initVT/0, myVTid/1, myVTvc/1, myCount/1, foCount/2, isVT/1, syncVT/2, tickVT/1, compVT/2, aftereqVTJ/2]).

% 3.2.2 siehe Schnittstelle VektoruhrADT
initVT() ->
    Log_file = "vectorC-init.log",
    PID = read_config_tower_clock("towerClock.cfg", Log_file),
    Init_VT = getVecID_by_tower_clock(Log_file, PID),
    util:logging(Log_file, "** Ausgabe des initialen Vektorzeitstempel " ++ util:to_String(Init_VT) ++  "\n"),
    Init_VT.

getVecID_by_tower_clock(Log_file, PID) -> 
    {PID_name, PID_node} = PID,
    case net_adm:ping(PID_node) of 
        pong -> 
            timer:sleep(1000),
            PID ! {getVecID, self()},
            receive 
                {vt, Pnum} -> 
                    util:logging(Log_file, "** Bei Tower-Clock eindeutige Prozess-ID (Pnum) erfragt: " ++ util:to_String(Pnum)++  "\n"),
                    VT_list = create_VT(Pnum, [], 1),
                    {Pnum, VT_list}

            end;
        pang -> 
            util:logging(Log_file, "** PING an "++ util:to_String(PID_name) ++ ": Anfrage einer eindeutigen Prozess-ID pnum fehlgeschlagen!\n"),
            null
    end.

% erzeugt initialen VT, wobei VT die Vektoruhrzeitstempel ist der Länge Pnum
% siehe Initialisierungsphase 3.3
create_VT(Pnum, VT, Pnum) ->
    VT ++ [0];
create_VT(Pnum, VT, Counter) -> 
    create_VT(Pnum, VT ++ [0], Counter + 1).

read_config_tower_clock(File_name, Log_file) -> 
    util:logging(Log_file,  util:to_String(File_name) ++ " geoeffnet..."++"\n"),
    {ok, Config_file} = file:consult(File_name),
    {ok, Server_name} = vsutil:get_config_value(servername, Config_file), 
    {ok, Server_node} = vsutil:get_config_value(servernode,Config_file),
    {Server_name, Server_node}.

% 3.2.2 siehe Schnittstelle VektoruhrADT
myVTid({Pnum, _VT_list}) -> 
    Pnum.

% 3.2.2 siehe Schnittstelle VektoruhrADT
myVTvc({_Pnum, VT_list}) ->
    VT_list.

% 3.2.2 siehe Schnittstelle VektoruhrADT
myCount(VT) ->
    {Pnum, _VT_list} = VT, 
    foCount(Pnum, VT).

% 3.2.2 siehe Schnittstelle VektoruhrADT
foCount(J, _VT) when J =< 0 -> 
    wrongIndexJ;
foCount(J, VT) ->
    case isVT(VT) of 
        true ->
            {_Pnum, VT_list} = VT, 
            get_J_from_VT_list(J, VT_list, 1);
        false -> 
            wrongInput
end.

% getter-Methode, um Element an Position J zu holen
get_J_from_VT_list(_J, [], _Index_counter) -> 
    0;
get_J_from_VT_list(J,[Event_counter | _Tail], J) -> 
    Event_counter;
get_J_from_VT_list(J, [_Elem | Tail], Index_counter) -> 
    get_J_from_VT_list(J, Tail, Index_counter + 1).


% 3.2.2 siehe Schnittstelle VektoruhrADT
% 3.3.2 Beschreibung isVT - Überprüfung der Datenstruktur (Abbildung 9)
isVT(Input) -> 
    if 
        (erlang:is_tuple(Input)) and (erlang:tuple_size(Input) == 2) -> 
            case erlang:is_list(myVTvc(Input)) of 
                true ->
                    ID = myVTid(Input),
                    (erlang:is_number(ID)) and (ID =< length(myVTvc(Input), 0)) and elems_are_number(myVTvc(Input));
                false -> 
                    false
            end;
        true -> 
            false
    end.

length([], Counter) -> 
    Counter;
length([_H|T], Counter) -> 
    length(T, Counter +1).

elems_are_number([]) -> 
    true;
elems_are_number([Elem|T]) ->
    if 
        erlang:is_number(Elem) -> 
            elems_are_number(T);
        true -> 
            false
end.

% 3.2.2 siehe Schnittstelle VektoruhrADT
% bildet den elementweise Maximum zwischen der Vektoruhrzeitstempel von VT1 und VT2
syncVT(VT1, VT2) -> 
    Synced_VT = build_syncVT(myVTvc(VT1), myVTvc(VT2), []),
    {myVTid(VT1), Synced_VT}.

build_syncVT([], [], Sync_VT) -> 
    Sync_VT;
build_syncVT([Own_event_counter | Tail], [], Sync_VT) -> 
    build_syncVT(Tail, [], Sync_VT ++ [Own_event_counter]);
build_syncVT([], [Other_event_counter | Tail], Sync_VT) ->
    build_syncVT([], Tail, Sync_VT ++ [Other_event_counter]);
build_syncVT([Own_event_counter | Own_tail], [Other_event_counter | Other_tail], Sync_VT) ->
    if 
        Own_event_counter >= Other_event_counter -> 
            build_syncVT(Own_tail, Other_tail, Sync_VT ++ [Own_event_counter]);
        true -> 
            build_syncVT(Own_tail, Other_tail, Sync_VT ++ [Other_event_counter])
end.

% 3.2.2 siehe Schnittstelle VektoruhrADT
% Inkrementiert den eigenen Ereigniszähler um 1
tickVT(VT) ->
    case isVT(VT) of
        true ->
            Modified_VT = increment_pnum_in_VT_list(myVTid(VT), myVTvc(VT), 1, []),
            {myVTid(VT), Modified_VT};
        false -> 
            wrongInput
end.

increment_pnum_in_VT_list(_Pnum, [], _Index_counter, New_VT_list) -> 
    New_VT_list;
increment_pnum_in_VT_list(Pnum, [Event_counter | Tail], Pnum, New_VT_list) -> 
    increment_pnum_in_VT_list(Pnum, Tail, Pnum + 1, New_VT_list ++ [Event_counter + 1]);
increment_pnum_in_VT_list(Pnum,[Event_counter | Tail], Counter, New_VT_list) -> 
    increment_pnum_in_VT_list(Pnum, Tail, Counter + 1, New_VT_list ++ [Event_counter]).

% 3.2.2 siehe Schnittstelle VektoruhrADT
% Vergleich zweier Vektoruhren, Ergebnis (afterVT, beforeVT, equalVT oder concurrentVT)
compVT(VT1, VT2) ->
    case isVT(VT1) and isVT(VT2) of
        true ->
            comp_VT_list(myVTvc(VT1), myVTvc(VT2), equalVT);
        false -> 
            wrongInput
end.

% Flussdiagramm  Abbildung 10
comp_VT_list([], [], State) -> 
    State;
comp_VT_list( [H|T], [], State) when H > 0-> 
    case State of
        beforeVT -> 
            concurrentVT;
        State -> 
            comp_VT_list(T, [], afterVT)
    end;
comp_VT_list([], [H|T], State) when H > 0-> 
    case State of
        afterVT -> 
            concurrentVT;
        State -> 
            comp_VT_list([], T, beforeVT)
    end;
comp_VT_list([H|T], [], State) when H == 0-> 
    comp_VT_list(T, [], State);
comp_VT_list([], _List2 = [H|T], State) when H == 0-> 
    comp_VT_list([], T, State);
comp_VT_list([Elem_other|Tail_own], [Elem2|Tail_other], State) when Elem_other > Elem2 ->
    if 
        State == beforeVT ->
            concurrentVT;
        true -> 
            comp_VT_list(Tail_own, Tail_other, afterVT)
    end;
comp_VT_list([Elem_other|Tail_own], [Elem2|Tail_other], State) when Elem_other < Elem2 ->
    if 
        State == afterVT ->
            concurrentVT;
        true -> 
            comp_VT_list(Tail_own, Tail_other, beforeVT)
    end;
comp_VT_list([Elem|Tail_own], [Elem|Tail_other], State) ->
    comp_VT_list(Tail_own, Tail_other, State).
    
% 3.2.2 siehe Schnittstelle VektoruhrADT und Abbildung 11
% untersucht nach Auslieferungskriterium für VTR, ob VT und VTR in unmittelbarer Abhängigkeit stehen
% Kapitel 2 Algoritihmus siehe unter Empfang-Ereignis
aftereqVTJ(VT, VTR) -> 
    case isVT(VT) and isVT(VTR) of
        true -> 
            % 1.Bedingung: vergleiche die Vektorzeitstempel von VT und VTR ohne Position J zu berücksichtigen
            VC_without_J = create_VT_List_withoutJ(myVTvc(VT), [], myVTid(VTR), 1), 
            VCR_without_J = create_VT_List_withoutJ(myVTvc(VTR), [], myVTid(VTR),1),
            case comp_VT_list(VC_without_J, VCR_without_J,  equalVT) of 
                Answer when (Answer == afterVT) or (Answer == equalVT) -> 
                    % 2. Bedingung: berechne die Distanz an Position J 
                    {aftereqVTJ, foCount(myVTid(VTR), VT) - myCount(VTR)};
                Answer when (Answer == beforeVT) or (Answer == concurrentVT) ->
                    false
            end;
        false -> 
            wrongInput
end.

% erzeugt List ohne Position J zu berücksichtigen
create_VT_List_withoutJ([], New_VT, _J, _Index_counter) -> 
    New_VT;
create_VT_List_withoutJ([_Elem|T], New_VT, J, J) -> 
    create_VT_List_withoutJ(T, New_VT, J, J + 1);
create_VT_List_withoutJ([Elem|T], New_VT, J, Index_counter) ->
    create_VT_List_withoutJ(T, New_VT ++ [Elem], J, Index_counter +1).