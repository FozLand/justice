# Justice Mod

The justice mod provides an system to manage temporary player restrictions.
A judge privilege enables the 'judge' to convict and sentence other players
to prison for a specified number of seconds. The mod revokes the convicted
player's shout, interact, and home privileges and then confines them to
configurable jail cell locations. The player's position is monitored for the
duration of their prison sentence to make sure they stay near the cell's
location. The convicted player is presented with a form explaining the
procedure, and with a HUD timer to track their time served and indicate when
they will be released from prison. The time served only counts while the player
is logged into the server. A record of all convictions is maintained in a
justice sub-folder within the world directory, and the records for each player
can be viewed in game. Sentencing an already imprisoned player adds the new
sentence to there remaining previous sentence. While escape should be
impossible from a closed prison cell, players who do manage to escape are
automatically returned to prison with a doubled sentence.

		Examples:
		/convict Foz 60 arson     -- sentenced to 60 seconds in prison for arson
		/convict Foz 60 vandalism -- sentenced to 60 seconds in prison for vandalism
		/convict Foz 240 murder   -- sentenced to 4 minutes in prison for murder
		/parole Foz               -- discharge Foz from prison immediately
		/records Foz              -- list Foz's complete criminal record
		/inmates                  -- list all inmates currently logged-in

The mod also detects direct assaults and murders. Offenders are automatically
convicted and sentenced to 30 and 240 seconds in prison respectively. PVP zones
can be defined to disable the detection within a certain area or areas.
Further, safe zones can be defined within those PVP zones to turn detection
back on. This allows for arbitrary and complex zoning layouts, such as
protected roads or rooms within hostile areas, or PVP arenas with safe
spectator zones. Zone determination is bases on the victim's location rather
than the perpetrator's.

At the moment, the prison cells, release point, pvp and safe zones are all hard
coded. In game configuration is planned for future development.
