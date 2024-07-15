```plantuml

== "Beendigungsphase einer Kommunikationseinheit" == 

Admin -> BotA : stop(BotA)
BotA -> BotA : kill HBQ und DLQ 
BotA -> VektorADT: request, kill
Admin <-- BotA : done


@enduml


```

