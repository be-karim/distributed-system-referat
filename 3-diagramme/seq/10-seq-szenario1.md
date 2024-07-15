```plantuml

title **Kausal perfekter Ablauf**

== "Init" == 

PA -> PA : [0]
PB -> PB : [0,0]
PC -> PC : [0,0,0]

== "send K1" == 


PA -> PA : tick [0] -> [1]
PA -> PA : send K1
PA -> PA : sync [0] und [1] -> [1]
PA -> PB : send K1
PB -> PB : sync [0,0] und [1] -> [1,0]
PA -> PC : send K1
PC -> PC : sync [0,0, 0] und [1] -> [1,0,0]

== "send K2" == 

PC -> PC : tick [1,0,0] -> [1,0,1]
PC -> PC : send K2
PC -> PC : sync [1,0,0] und [1,0,1] -> [1,0,1]
PC -> PB : send K1
PB -> PB : sync [1,0] und [1,0,1] -> [1,0,1]
PC -> PA : send K1
PA -> PA : sync [1] und [1,0,1] -> [1,0,1]

== "send K3" == 

PC -> PC : tick [1,0,0] -> [1,0,1]
PC -> PC : send K2
PC -> PC : sync [1,0,0] und [1,0,1] -> [1,0,1]
PC -> PB : send K1
PB -> PB : sync [1,0] und [1,0,1] -> [1,0,1]
PC -> PA : send K1
PA -> PA : sync [1] und [1,0,1] -> [1,0,1]






@enduml


```



