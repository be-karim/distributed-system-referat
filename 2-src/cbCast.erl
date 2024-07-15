-module(cbCast).

-author("Belal Karimzai").

-export([init/0, stop/1, send/2,send/3, read/1, received/1]).
% -compile(export_all).

% 3.2.2 siehe Schnittstelle Kommunikationeinheit
init() -> 
    PID_tower_cbc = read_config_tower_cbc(),
    Result = rand:uniform(1000),
    PID = spawn(fun() -> 
        % selbst-definierte Log-file
        Log_file = "cbCast-"++util:to_String(self())++ util:to_String(Result) ++".log",
        register_by_tower_cbc(Log_file, PID_tower_cbc), 
        % initiales VT erzeugen
        InitVT = vectorC:initVT(),
        listen(InitVT, {[], []}, PID_tower_cbc, Log_file)
    end),
    Log_file_Extern = "cbCast-"++util:to_String(PID)++ util:to_String(Result) ++".log",
    util:logging(Log_file_Extern, "Startzeit " ++ util:timeMilliSecond() ++  " des Prozesses"++ util:to_String(PID) ++"\n"),
    PID.


read_config_tower_cbc() -> 
    {ok, Config_file} = file:consult("towerCBC.cfg"),
    {ok, Server_name} = vsutil:get_config_value(servername, Config_file), 
    {ok, Server_node} = vsutil:get_config_value(servernode,Config_file),
    {Server_name, Server_node}.

% 3.3.1 Initialisierungsphase - Registrierung bei der Multicast-Zentrale
register_by_tower_cbc(Log_file, PID) -> 
    {PID_name, PID_node} = PID,
    case net_adm:ping(PID_node) of 
        pong -> 
            timer:sleep(1000),
             % 3.2.2 siehe Schnittstelle Multicast-Zentrale
            PID ! {self(), {register, self()}},
            receive 
                Status -> 
                    util:logging(Log_file, "** Beim TowerCBC registriert: " ++ util:to_String(Status)++  "\n")
            end;
        pang -> 
            util:logging(Log_file, "** PING an "++ util:to_String(PID_name) ++ ": Verbindung mit" ++ util:to_String(PID) ++ " fehlgeschlagen -->  Registrierung bei towerCBC nicht moeglich \n")
    end.

% 3.2.2 siehe Schnittstelle Kommunikationeinheit
stop(Comm) -> 
    Comm ! {self(), stop}, 
    receive 
        done -> 
            done
    after 3000 -> 
            null
end.

% 3.2.2 selbst erweiterte Schnittstelle Kommunikationeinheit
send(Comm, Message, Blocking) -> 
    Comm ! {send, Message, Blocking}, 
    done.

% 3.2.2 siehe Schnittstelle Kommunikationeinheit
send(Comm, Message) -> 
    Comm ! {send, Message, true}, 
    done.

% 3.2.2 siehe Schnittstelle Kommunikationeinheit
read(Comm) -> 
    Comm ! {self(), read, true}, 
    receive 
        null -> 
            null;
        Elem -> 
            Elem
    end.

% 3.2.2 siehe Schnittstelle Kommunikationeinheit
received(Comm) -> 
    Comm ! {self(), read, false}, 
    % solange blockierend, bis ein Element, also eine Nachricht eintrifft
    receive 
        Elem -> 
            Elem
end.

listen(Local_VT, {HBQ, DLQ}, PID_tower_cbc, Log_file) ->
    receive 
        % 3.2.2 selbst erweitertes Nachrichtenformat, um den Befehl send zu bearbeiten
        % 3.3.1 Sendeereignis
        {send, Message, Blocking} -> 
            util:logging(Log_file, " ** send Message : " ++ util:to_String(Message) ++ " an PID: " ++ util:to_String(PID_tower_cbc) ++  " \n"),
            util:logging(Log_file, ">>>> lokale VT: " ++ util:to_String(Local_VT) ++ "\n"),
        % Sendeereignis bedarf ein Inkrement der lokalen Vektoruhr
            New_local_VT = vectorC:tickVT(Local_VT), 
            util:logging(Log_file, ">>>> lokale VT nach tick: " ++ util:to_String(New_local_VT) ++ "\n"),
            util:logging(Log_file, ">>>> DLQ: " ++ util:to_String(DLQ) ++ "\n"),
        % Füge lokales Element in die DLQ - erfüllt die FIFO-Ordnung
            New_DLQ = push_to_dlq(DLQ, {Message, New_local_VT}),
            util:logging(Log_file, "DLQ>>> Nachricht" ++ Message ++ "von Prozess " ++ util:to_String(vectorC:myVTid(New_local_VT)) ++ " mit Zeitstempel" ++ util:to_String(vectorC:myVTvc(New_local_VT)) ++ "in DLQ eingefuet\n"),
            util:logging(Log_file, "HBQ>>> Pruefung auf auslieferbare Nachrichten ("++util:to_String(New_local_VT)++").\n"),
        % Überprüfe, ob Nachrichten in die DLQ überführbar sind
            Modified_Queues = check_message_to_deliver(HBQ, [], New_DLQ, New_local_VT, Log_file), 
            if 
                % 3.2.2 siehe Schnittstelle Multicast-Zentrale
                Blocking -> 
                    PID_tower_cbc ! {self(), {multicastB, {Message, New_local_VT}}},
                    util:logging(Log_file, ">>>> blockierend Nachricht an Multicast gesendet. send ende ** \n");
                true -> 
                    PID_tower_cbc ! {self(), {multicastNB, {Message, New_local_VT}}},
                    util:logging(Log_file, ">>>> nicht blockierend Nachricht an Multicast gesendet. send ende ** \n")
            end,
            listen(New_local_VT, Modified_Queues, PID_tower_cbc, Log_file);
        % 3.2.2 siehe Schnittstelle Kommunikationseinheit
        % 3.3.1 Empfangereignis - Middleware erhält multicast-Nachricht
        {PID,{castMessage, Incoming_Message}} ->
            Modified_Queues = receive_message(Incoming_Message, PID, Local_VT, HBQ, DLQ, Log_file),
            listen(Local_VT, Modified_Queues, PID_tower_cbc, Log_file);
         % 3.2.2 selbst erweitertes Nachrichtenformat, um den Befehl read bzw. received auszuführen
         % 3.3.1 Leseabfrage eines Clients
        {PID, read, Not_blocking} -> 
            {Synced_VT, Modified_Queues} = read_message(PID, Not_blocking, Local_VT, {HBQ, DLQ}, Log_file),
            listen(Synced_VT, Modified_Queues, PID_tower_cbc, Log_file);
        % 3.2.2 selbst erweitertes Nachrichtenformat, um den Prozess zu termineiren
        {PID, stop} -> 
            util:logging(Log_file, " ** stop Prozess " ++ util:to_String(self()) ++ "\n"),
            util:logging(Log_file, ">>>> DLQ kill um " ++ util:timeMilliSecond() ++ " mit " ++ util:to_String(length_List(DLQ)) ++ "\n"),
            util:logging(Log_file, " verbleibende Nachrichten in DLQ: " ++ util:to_String(DLQ) ++ "\n"),
            util:logging(Log_file, ">>>> HBQ: kill um " ++ util:timeMilliSecond() ++ " mit " ++ util:to_String(length_List(HBQ)) ++ "\n"),
            util:logging(Log_file, " verbleibende Nachrichten in HBQ: " ++ util:to_String(HBQ) ++ "\n"),
            util:logging(Log_file, ">>>> VT kill um "++ util:timeMilliSecond() ++ "\n"),
            util:logging(Log_file, " aktueller Zustand von VT: " ++ util:to_String(Local_VT) ++ "\n"),
            PID ! done
end.

receive_message(Incoming_Message = {MSG, VT}, PID, Local_VT, HBQ, DLQ, Log_file) -> 
    util:logging(Log_file, "** receive message \n"),
    % da lokale NAchrichten in der DLQ überführt worden, werden Nachrichten mit gleicher Pnum_id ignoriert (Abbildung 6)
    case vectorC:myVTid(Local_VT) == vectorC:myVTid(VT) of 
        false -> 
            New_HBQ = push_to_hbq(HBQ, Incoming_Message, Log_file),
            util:logging(Log_file, "HBQ>>> Nachricht "++ MSG  ++ " von Prozess " ++ util:to_String(vectorC:myVTid(VT)) ++ " mit PID: " ++ util:to_String(PID) ++ " mit Zeitstempel "++ util:to_String(vectorC:myVTvc(VT)) ++ " in HBQ eingefuegt.\n");
        true -> 
            util:logging(Log_file, "HBQ>>> Nachricht "++ MSG  ++ " von Prozess " ++ util:to_String(vectorC:myVTid(VT)) ++ " mit PID: " ++ util:to_String(PID) ++ " mit Zeitstempel "++ util:to_String(vectorC:myVTvc(VT)) ++ " befindet sich bereits in DLQ. Nachricht wurde nicht eingefügt! \n"),
            New_HBQ = HBQ
    end,
    util:logging(Log_file, "HBQ>>> Pruefung auf auslieferbare Nachrichten ("++util:to_String(Local_VT)++").\n"),
    New_Queues = {Modified_HBQ, Modified_DLQ} = check_message_to_deliver(New_HBQ, [], DLQ, Local_VT, Log_file), 
    util:logging(Log_file, "> New_HBQ: " ++ util:to_String(Modified_HBQ) ++ "\n"),
    util:logging(Log_file, "> New_DLQ: " ++ util:to_String(Modified_DLQ) ++ "\n"),
    util:logging(Log_file, "** receive message END ** \n"),
    New_Queues.

read_message(PID, Not_blocking, Local_VT, {HBQ, DLQ}, Log_file) ->
    % Verarbeitung der Leseanfrage (Abbildung 7)
    util:logging(Log_file, "** read message \n"),
    util:logging(Log_file, "> HBQ: " ++ util:to_String(HBQ) ++ "\n"),
    util:logging(Log_file, "> DLQ: " ++ util:to_String(DLQ) ++ "\n"),
    util:logging(Log_file, "HBQ>>> Pruefung auf auslieferbare Nachrichten ("++util:to_String(Local_VT)++").\n"),
    {Modified_HBQ, Modified_DLQ} = check_message_to_deliver(HBQ,[], DLQ, Local_VT, Log_file),
    case is_message_to_deliver(Modified_DLQ) of
        {{Message, VT}, New_DLQ} ->
             % Synchronisierung der VTs
            New_VT = vectorC:syncVT(Local_VT, VT),
            if 
                Not_blocking -> 
                    util:logging(Log_file, "DLQ>>> Nachricht "++ Message ++ " von Prozess "++util:to_String(vectorC:myVTid(VT))++" mit Zeitstempel "++util:to_String(vectorC:myVTvc(VT))++" aus DLQ geloescht (nicht blockierend).\n");
                true -> 
                    util:logging(Log_file, "DLQ>>> Nachricht "++ Message ++ " von Prozess "++util:to_String(vectorC:myVTid(VT))++" mit Zeitstempel "++util:to_String(vectorC:myVTvc(VT))++" aus DLQ geloescht (blockierend).\n")
            end,
            New_HBQ = Modified_HBQ,
            PID ! Message;
        null -> 
            if 
                Not_blocking -> 
                    util:logging(Log_file, "** Keine Nachricht zum Lesen (nicht blockierend) **\n"),
                    PID ! null, 
                    New_VT = Local_VT, New_DLQ = Modified_DLQ, New_HBQ = Modified_HBQ;
                true -> 
                    util:logging(Log_file, "** Keine Nachricht zum Lesen (blockierend) **\n"),
                    % auf eine auslieferbare Nachrichten warten, um diese den blockierenen Client auszuliefern
                    {New_VT, New_DLQ, New_HBQ} = wait_for_message_to_deliver(PID, Local_VT, Modified_HBQ, Modified_DLQ, Log_file)
            end
    end, 
    util:logging(Log_file, ">> Synchronisierte Vektoruhr: ("++util:to_String(New_VT)++").\n"),
    util:logging(Log_file, "> Modified_HBQ: " ++ util:to_String(New_HBQ) ++ "\n"),
    util:logging(Log_file, "> Modified_DLQ: " ++ util:to_String(New_DLQ) ++ "\n"),
    util:logging(Log_file, "** read message END ** \n"),
    {New_VT, {New_HBQ, New_DLQ}}.

push_to_hbq(HBQ, Elem, Log_file) -> push_to_hbq(HBQ, [], Elem, Log_file).

push_to_hbq([], New_HBQ, New_elem, Log_file) -> 
    util:logging(Log_file, "** push_to_hbq: Am Ende der Liste angekommen. Element hinten angefügt  \n"),
    New_HBQ ++ [New_elem];
push_to_hbq(Rest = [Elem_HBQ = {_Message_in_hbq, VT_in_hbq} | Tail], New_HBQ, New_elem = {_Message, New_VT}, Log_file) -> 
    % sortierte HBQ-Struktur durch die Vergleichsmethode compVT gewährleistet (Abbildung 10)
    Result = vectorC:compVT(VT_in_hbq, New_VT), 
    util:logging(Log_file, ">> Vergleich: VT1: " ++ util:to_String(VT_in_hbq) ++ " mit VT2: " ++ util:to_String(New_VT) ++ "\n"),
    util:logging(Log_file, ">> Result: " ++ util:to_String(Result) ++ "\n"),
    if 
        ((Result == beforeVT) or (Result == concurrentVT)) -> 
            push_to_hbq(Tail, New_HBQ ++ [Elem_HBQ], New_elem, Log_file);
        Result == afterVT  -> 
            Result_HBQ = New_HBQ ++ [New_elem] ++ Rest, 
            util:logging(Log_file, "** push_to_hbq: Element eingefügt zwischen: \n"),
            util:logging(Log_file, "**" ++ util:to_String(New_HBQ) ++ " -- Elem" ++ util:to_String(New_elem) ++ "-- " ++ util:to_String(Rest) ++ " **\n"),
            util:logging(Log_file, "> New_HBQ: " ++ util:to_String(Result_HBQ) ++ "\n"),
            Result_HBQ;
        true -> 
            Old_HBQ = New_HBQ ++ Rest,
            util:logging(Log_file, "> Old_HBQ: " ++ util:to_String(Old_HBQ) ++ "\n"),
            util:logging(Log_file, "Vergleich von TODO"),
            util:logging(Log_file, "** push_to_hbq ENDE  \n"),
            Old_HBQ
    end.

push_to_dlq(DLQ, Elem) -> DLQ ++ [Elem].

% überprüft, ob eine Nachricht aus der HBQ an die DLQ überführbar ist
% Überprüfung erfolgt mittels der Methode aftereqVTJ (siehe in vectorC.erl)
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


wait_for_message_to_deliver(Reader_PID, Local_VT, HBQ, DLQ, Log_file) -> 
    % 3.4 Reflexion der Vorgehensweise unter "Blockierendes Ausliefern der Nachrichten"
    receive 
        {PID,{castMessage, Incoming_Message}} ->
            {New_HBQ, New_DLQ} = receive_message(Incoming_Message, PID, Local_VT, HBQ, DLQ, Log_file);
        Other -> 
            util:logging(Log_file, "** Zurzeit wird nur der Empfangsservice für Multicast-Nachrichten angeboten, da der Client " ++ util:to_String(Reader_PID) ++ " eine Nachricht empfangen möchte **\n"),
            {New_HBQ, New_DLQ} = {HBQ, DLQ}
    end, 
    case is_message_to_deliver(New_DLQ) of 
        {{Message, VT}, Modified_DLQ} -> 
            % Synchronisierung der VTs
            New_local_VT = vectorC:syncVT(Local_VT, VT),
            Reader_PID ! Message,
            {New_local_VT,New_HBQ, Modified_DLQ};
        null -> 
            wait_for_message_to_deliver(Reader_PID, Local_VT, New_HBQ, New_DLQ, Log_file)
end.

is_message_to_deliver([]) -> null;
is_message_to_deliver([Elem|Tail]) -> {Elem, Tail}.

length_List(List) -> len(List, 0).

len([],Counter) -> 
    Counter;
len([_H|T], Counter) -> 
    len(T, Counter +1).