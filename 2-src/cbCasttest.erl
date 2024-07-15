-module(cbCasttest).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).

is_message_deliverable_to_dlq_test() -> 
    VT1 = {1, [1]},
    VT2 = {2, [2,1]},
    DLQ = [{"a", VT1}],
    HBQ = [{"b", VT2}],
    true = cbCast:is_message_deliverable_to_dlq(HBQ, DLQ).


contains_elem_test() ->
    VT1 = {1, [1]},
    VT2 = {2, [2,1]},
    VT3 = {3, [2,1,3]},
    HBQ = [{"a", VT2}, {"b", VT3}, {"c", VT1}],
    true = cbCast:not_existing(HBQ, {3,[1,1,3]}),
    false = cbCast:not_existing(HBQ, {3,[2,1,3]}).


szenario1_test() ->
    Log_file = "szenario1.log",
    Pnum2 = 2,
    Pnum3 = 3,
    Init_VT = {1,[0]},
    DLQ = [],
    HBQ = [],
    % sende Nachricht A von Pnum1  
    A = "a",
    util:logging(Log_file, "sende Nachricht A von Pnum1  \n"),
    {Local_VT1, Modified_HBQ1, Modified_DLQ1} = send_message(A, Init_VT, HBQ, DLQ, Log_file),
    util:logging(Log_file, "> New_HBQ: " ++ util:to_String(Modified_HBQ1) ++ "\n"),
    util:logging(Log_file, "> New_DLQ: " ++ util:to_String(Modified_DLQ1) ++ "\n"),
    % sende Nachricht B von Pnum1  
    B = "b", 
    util:logging(Log_file, "sende Nachricht B von Pnum1  \n"),
    {Local_VT2, Modified_HBQ2, Modified_DLQ2} = send_message(B, Local_VT1, Modified_HBQ1, Modified_DLQ1, Log_file),
    util:logging(Log_file, "> New_HBQ: " ++ util:to_String(Modified_HBQ2) ++ "\n"),
    util:logging(Log_file, "> New_DLQ: " ++ util:to_String(Modified_DLQ2) ++ "\n"),
    % erhalte Nachricht C von Pnum2
    C = "c",
    Message1 = {C, {Pnum2, [0,1] }},
    util:logging(Log_file, "erhalte Nachricht C von Pnum2  \n"),
    {Modified_HBQ3, Modified_DLQ3} = receive_message(Message1, Local_VT2, Modified_HBQ2, Modified_DLQ2, Log_file),
    util:logging(Log_file, "> New_HBQ: " ++ util:to_String(Modified_HBQ3) ++ "\n"),
    util:logging(Log_file, "> New_DLQ: " ++ util:to_String(Modified_DLQ3) ++ "\n"),
    % erhalte Nachricht D von Pnum3
    D = "d",
    Message2 = {D, {Pnum3, [0,0,1] }},
    util:logging(Log_file, "erhalte Nachricht D von Pnum3  \n"),
    {Modified_HBQ4, Modified_DLQ4} = receive_message(Message2, Local_VT2, Modified_HBQ3, Modified_DLQ3, Log_file),
    util:logging(Log_file, "> New_HBQ: " ++ util:to_String(Modified_HBQ4) ++ "\n"),
    util:logging(Log_file, "> New_DLQ: " ++ util:to_String(Modified_DLQ4) ++ "\n"),
    % erhalte Nachricht E von Pnum3
    {Modified_HBQ5, Modified_DLQ5} = do_receive("g", Pnum3, [0,0,2], Local_VT2, Modified_HBQ4, Modified_DLQ4, Log_file),
     % erhalte Nachricht G von Pnum2
    {Modified_HBQ6, Modified_DLQ6} = do_receive("g", Pnum2, [0,3], Local_VT2, Modified_HBQ5, Modified_DLQ5, Log_file),
    % erhalte Nachricht F von Pnum2
    {Modified_HBQ7, Modified_DLQ7} = do_receive("f", Pnum2, [0,2], Local_VT2, Modified_HBQ6, Modified_DLQ6, Log_file),
    % erhalte Nachricht H von Pnum3
    {Modified_HBQ8, Modified_DLQ8} = do_receive("h", Pnum3, [0,0,3], Local_VT2, Modified_HBQ7, Modified_DLQ7, Log_file),
    {Local_VT9, Modified_HBQ9, Modified_DLQ9} = read_message(Local_VT2, Modified_HBQ8, Modified_DLQ8, Log_file),
    {Local_VT10, Modified_HBQ9, Modified_DLQ10} = read_message(Local_VT9, Modified_HBQ9, Modified_DLQ9, Log_file),
    {Local_VT11, Modified_HBQ11, Modified_DLQ11} = read_message(Local_VT10, Modified_HBQ9, Modified_DLQ10, Log_file),
    {Modified_HBQ12, Modified_DLQ12} = do_receive("z", Pnum3, [2,3,4], Local_VT11, Modified_HBQ11, Modified_DLQ11, Log_file),
    {Modified_HBQ13, Modified_DLQ13} = do_receive("l", Pnum2, [0,4], Local_VT11, Modified_HBQ12, Modified_DLQ12, Log_file),
    {Local_VT14, Modified_HBQ14, Modified_DLQ14} = read_message(Local_VT11, Modified_HBQ13, Modified_DLQ13, Log_file),
    {Modified_HBQ15, Modified_DLQ15} = do_receive("l", Pnum3, [2,5,4], Local_VT14, Modified_HBQ14, Modified_DLQ14, Log_file),
    {Local_VT16, Modified_HBQ16, Modified_DLQ16} = read_message(Local_VT14, Modified_HBQ15, Modified_DLQ15, Log_file),
    {Local_VT17, Modified_HBQ17, Modified_DLQ17} = read_message(Local_VT16, Modified_HBQ16, Modified_DLQ16, Log_file).



do_receive(MSG, Pnum, VT_list, Local_VT, HBQ, DLQ, Log_file) -> 
    Message = {MSG, {Pnum, VT_list }},
    util:logging(Log_file, "erhalte Nachricht <" ++ MSG ++ "> von Pnum" ++ util:to_String(Pnum) ++ "\n"),
    {Modified_HBQ, Modified_DLQ} = receive_message(Message, Local_VT, HBQ, DLQ, Log_file),
    util:logging(Log_file, "> New_HBQ: " ++ util:to_String(Modified_HBQ) ++ "\n"),
    util:logging(Log_file, "> New_DLQ: " ++ util:to_String(Modified_DLQ) ++ "\n"),
    {Modified_HBQ, Modified_DLQ}.
 

send_message(Message, Local_VT, HBQ, DLQ, Log_file) -> 
    New_local_VT = {Pnum1, VT1} = vectorC:tickVT(Local_VT),
    New_DLQ = cbCast:push_to_dlq(DLQ, {Message, New_local_VT}),
    util:logging(Log_file, "DLQ>>> Nachricht" ++ Message ++ "von Prozess " ++ util:to_String(Pnum1) ++ " mit Zeitstempel" ++ util:to_String(VT1) ++ "in DLQ eingefuet\n"),
    util:logging(Log_file, "HBQ>>> Pruefung auf auslieferbare Nachrichten ("++util:to_String(New_local_VT)++").\n"),
    {Modified_HBQ, Modified_DLQ} = check_message_to_deliver(HBQ, [], New_DLQ, New_local_VT, Log_file), 
    {New_local_VT, Modified_HBQ, Modified_DLQ}.

receive_message(Incoming_Message, Local_VT, HBQ, DLQ, Log_file) -> 
    New_HBQ = cbCast:push_to_hbq(HBQ, Incoming_Message, Log_file),
    {MSG, {Pnum, VT }} = Incoming_Message,
    util:logging(Log_file, "HBQ>>> Nachricht "++ MSG  ++ " von Prozess " ++ util:to_String(Pnum) ++ " mit Zeitstempel "++ util:to_String(VT) ++ " in HBQ eingefuegt.\n"),
    util:logging(Log_file, "HBQ>>> Pruefung auf auslieferbare Nachrichten ("++util:to_String(Local_VT)++").\n"),
    {Modified_HBQ, Modified_DLQ} = check_message_to_deliver(New_HBQ, [], DLQ, Local_VT, Log_file).

read_message(Local_VT, HBQ, DLQ, Log_file) ->
    util:logging(Log_file, "HBQ>>> Pruefung auf auslieferbare Nachrichten ("++util:to_String(Local_VT)++").\n"),
    {Modified_HBQ, Modified_DLQ} = check_message_to_deliver(HBQ,[], DLQ, Local_VT, Log_file),
    case is_message_to_deliver(Modified_DLQ) of
        {{Message, VT}, New_DLQ} ->
            New_VT = vectorC:syncVT(Local_VT, VT),
            util:logging(Log_file, "DLQ>>> Nachricht "++ Message ++ " von Prozess "++util:to_String(vectorC:myVTid(VT))++" mit Zeitstempel "++util:to_String(vectorC:myVTvc(VT))++" aus DLQ geloescht (nicht blockierend).\n"),
            util:logging(Log_file, ">> Synchronisierte Vektoruhr: ("++util:to_String(New_VT)++").\n");
        null -> 
            New_VT = Local_VT,
            New_DLQ = Modified_DLQ,
            util:logging(Log_file, "** Keine Nachricht zum Lesen.\n")
    end, 
    {New_VT, Modified_HBQ, New_DLQ}.

check_message_to_deliver([], New_HBQ, DLQ, _VT, Log_file) -> 
    util:logging(Log_file, "HBQ>>> Pruefung auf auslieferbare Nachrichten beendet.\n"),
    {New_HBQ, DLQ};
check_message_to_deliver([Elem = {_Message, VTR} | T], New_HBQ, DLQ, VT, Log_file) ->
    util:logging(Log_file, "HBQ>>> Vergleich: " ++ util:to_String(VT) ++ " mit " ++ util:to_String(VTR) ++ "\n"),
    case vectorC:aftereqVTJ(VT, VTR) of 
        {aftereqVTJ, -1} -> 
            util:logging(Log_file, "HBQ>>> Ergebnis aftereqVTJ mit Distanz " ++ util:to_String(-1) ++ ". Nachricht wird in DLQ verschoben \n"),
            check_message_to_deliver(T, New_HBQ, DLQ ++ [Elem], VT, Log_file);
        {aftereqVTJ, Number} -> 
            util:logging(Log_file, "HBQ>>> Ergebnis aftereqVTJ mit Distanz " ++ util:to_String(Number) ++ ". Nachricht bleibt in HBQ \n"),
            check_message_to_deliver(T, New_HBQ ++ [Elem], DLQ, VT, Log_file)
end.

is_message_to_deliver([]) -> null;
is_message_to_deliver([Elem|Tail]) -> {Elem, Tail}.