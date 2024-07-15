-module(szenario1).

-compile(export_all).

szenario1_test() ->
    Log_file = "szenario2.log",
    Pnum1 = 1,
    Pnum2 = 2,
    Pnum3 = 3,
    Init_VT = {1,[0]},
    DLQ = [],
    HBQ = [],
    {Local_VT1, Queue1} = send_message("hallo", Pnum1, Init_VT, {HBQ, DLQ}, Log_file),
    {Local_VT2, Queue2} = send_message("b", Pnum1, Local_VT1, Queue1, Log_file),
    Queue3 = do_receive("c", Pnum2, [0,1], Local_VT2, Queue2, Log_file),
    Queue4 = do_receive("d", Pnum3, [0,0,1], Local_VT2, Queue3, Log_file),
    Queue5 = do_receive("g", Pnum3, [0,0,2], Local_VT2, Queue4, Log_file),
    Queue6 = do_receive("g", Pnum2, [0,3], Local_VT2, Queue5, Log_file),
    Queue7 = do_receive("f", Pnum2, [0,2], Local_VT2, Queue6, Log_file),
    Queue8 = do_receive("h", Pnum3, [0,0,3], Local_VT2, Queue7, Log_file),
    {Local_VT9, Queue9} = read_message(Local_VT2, Queue8, Log_file),
    {Local_VT10, Queue10} = read_message(Local_VT9, Queue9, Log_file),
    {Local_VT11, Queue11} = read_message(Local_VT10, Queue10, Log_file),
    Queue12 = do_receive("z", Pnum3, [2,3,4], Local_VT11, Queue11, Log_file),
    Queue13 = do_receive("l", Pnum2, [0,4], Local_VT11, Queue12, Log_file),
    {Local_VT14, Queue14} = read_message(Local_VT11, Queue13, Log_file),
    Queue15 = do_receive("l", Pnum3, [2,5,4], Local_VT14, Queue14, Log_file),
    {Local_VT16, Queue16} = read_message(Local_VT14, Queue15, Log_file),
    {Local_VT17, Queue17} = read_message(Local_VT16, Queue16, Log_file),
    read_message(Local_VT17, Queue17, Log_file).



do_receive(MSG, Pnum, VT_list, Local_VT, {HBQ, DLQ}, Log_file) -> 
    Message = {MSG, {Pnum, VT_list }},
    util:logging(Log_file, "erhalte Nachricht <" ++ MSG ++ "> von Pnum" ++ util:to_String(Pnum) ++ "\n"),
    {Modified_HBQ, Modified_DLQ} = receive_message(Message, Local_VT, HBQ, DLQ, Log_file),
    util:logging(Log_file, "> New_HBQ: " ++ util:to_String(Modified_HBQ) ++ "\n"),
    util:logging(Log_file, "> New_DLQ: " ++ util:to_String(Modified_DLQ) ++ "\n"),
    {Modified_HBQ, Modified_DLQ}.
 

send_message(Message, Pnum, Local_VT, {HBQ, DLQ}, Log_file) -> 
    util:logging(Log_file, "sende Nachricht"++ Message ++ "von Pnum" ++ util:to_String(Pnum) ++"\n"),
    New_local_VT = {Pnum1, VT1} = vectorC:tickVT(Local_VT),
    New_DLQ = cbCast:push_to_dlq(DLQ, {Message, New_local_VT}),
    util:logging(Log_file, "DLQ>>> Nachricht" ++ Message ++ "von Prozess " ++ util:to_String(Pnum1) ++ " mit Zeitstempel" ++ util:to_String(VT1) ++ "in DLQ eingefuet\n"),
    util:logging(Log_file, "HBQ>>> Pruefung auf auslieferbare Nachrichten ("++util:to_String(New_local_VT)++").\n"),
    {Modified_HBQ, Modified_DLQ} = check_message_to_deliver(HBQ, [], New_DLQ, New_local_VT, Log_file), 
    util:logging(Log_file, "** send message END ** \n"),
    {New_local_VT, {Modified_HBQ, Modified_DLQ}}.

receive_message(Incoming_Message, Local_VT, HBQ, DLQ, Log_file) -> 
    util:logging(Log_file, "** receive message \n"),
    New_HBQ = cbCast:push_to_hbq(HBQ, Incoming_Message, Log_file),
    {MSG, {Pnum, VT }} = Incoming_Message,
    util:logging(Log_file, "HBQ>>> Nachricht "++ MSG  ++ " von Prozess " ++ util:to_String(Pnum) ++ " mit Zeitstempel "++ util:to_String(VT) ++ " in HBQ eingefuegt.\n"),
    util:logging(Log_file, "HBQ>>> Pruefung auf auslieferbare Nachrichten ("++util:to_String(Local_VT)++").\n"),
    New_Queues = check_message_to_deliver(New_HBQ, [], DLQ, Local_VT, Log_file), 
    util:logging(Log_file, "** receive message END ** \n"),
    New_Queues.

read_message(Local_VT, {HBQ, DLQ}, Log_file) ->
    util:logging(Log_file, "** read message \n"),
    util:logging(Log_file, "> HBQ: " ++ util:to_String(HBQ) ++ "\n"),
    util:logging(Log_file, "> DLQ: " ++ util:to_String(DLQ) ++ "\n"),
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
    util:logging(Log_file, "> Modified_HBQ: " ++ util:to_String(Modified_HBQ) ++ "\n"),
    util:logging(Log_file, "> Modified_DLQ: " ++ util:to_String(New_DLQ) ++ "\n"),
    util:logging(Log_file, "** read message END ** \n"),
    {New_VT, {Modified_HBQ, New_DLQ}}.

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
            check_message_to_deliver(T, New_HBQ ++ [Elem], DLQ, VT, Log_file);
        false -> 
            util:logging(Log_file, "HBQ>>> Ergebnis aftereqVTJ: false Nachricht bleibt in HBQ \n"),
            util:logging(Log_file, "HBQ>>> Vergleich zwischen "++ util:to_String(VT) ++ " und " ++ util:to_String(VTR) ++ "\n"),
            check_message_to_deliver(T, New_HBQ ++ [Elem], DLQ, VT, Log_file)
end.

is_message_to_deliver([]) -> null;
is_message_to_deliver([Elem|Tail]) -> {Elem, Tail}.