# Infrastruktur für einen kausalen Multicast mittels Vektoruhr 

--------------------
Compilieren der Dateien:
--------------------
Zu dem Paket gehören die Dateien
towerClock.beam; towerCBC.beam; vectorC.beam; cbCast.beam
util.beam; vsutil.beam; 

sowie:
Readme.txt; towerCBC.cfg; towerClock.cfg

1> make:all().
% oder
1> c(<Dateiname>).
% oder
1> c(<Dateiname>,[debug_info]).

--------------------
Starten der Nodes:
--------------------
(w)erl -(s)name <towerCBC> -setcookie zummsel
(w)erl -(s)name <towerClock> -setcookie zummsel
(w)erl -(s)name <cbCast*> -setcookie zummsel

Starten der cbCast* (auf unterschiedlichen Nodes):
--------------------------
1>towerClock:init( ).
towerClock:cfg:
{servername, <Name auf der Node>}.
{servernode, <Node des Tower>}.

1>towerCBC:init(<manu|auto| >).
towerCBC:cfg:
{servername, <Name auf der Node>}.
{servernode, <Node des Tower>}.


Starten der Kommunikationseinheiten (auf unterschiedlichen Nodes):
--------------------------
3>cbCast:init().
greift auf towerCBC.cfg zu. Über die ADT vectorC wird auf towerClock.cfg zugegriffen.


Runterfahren:
-------------
2> Ctrl/Strg Shift G
-->q

Rücksetzen Variablen:
-------------
1> f(<VariablenName>).
2> f().

Anzeigen aller Variablen:
-------------
1> b().

Informationen zu Prozessen bzw. Modulen:
-------------
2> observer:start().
2> process_info(PID).
2> <Module>:module_info(). 

Debugger:
-------------
1> c(<Dateiname,[debug_info]>).
2> debugger:start().
% zB First Call ankreuzen
% Module>Interpret... Modul auswählen
% Step um schrittweise durchzulaufen