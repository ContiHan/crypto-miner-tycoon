# Bugs

* ~~v offline režimu neběží halving, je stopnutý~~ (FIXED)
* ~~v offline režimu to vypadá, že se income počítá jinak, než podle vzorečku pro aktivní režim, je to subjektivní pocit, protože když to otevřu po několik minutách, tak to nageneruje pocitově víc, než kdybych tam celou dobu byl (je to subjektivní pocit, nevím, jak to změřit, když se v čase mění difficulty, je to takový bug k diskuzi)~~ (FIXED)
* ~~po hard forku se neresetuje reward~~ (FIXED)
* záložka LAB balance
  * ~~text s hodnotou ballance je pouze v hodnotě BTC, ale je tam špatný symbol pro měnu, když jsem v úrovni SATs, tak to ukazuje sice správnou hodnotu, ale symbol je ₿~~ (FIXED)
  * ~~po přepnutí na USD se zde pořád zobrazuje BTC hodnota~~ (FIXED)
  * ~~chybí mi možnost přepnout mezi BTC na USD a obráceně~~ (FIXED)
* výzkum solar power má v popisku coming soon, takže výzkum nefuguje? je bez dopadu?
* news floating
  * ~~text má v případě pozitivního nebo negativního dopadu špatné UX, protože v závorce je občas jen nějaké číslo, nejlepší by bylo explicitně napsat, že třeba dočasně spadl hashrate o 25 % / konkrétní číslo například 12k nebo že ti někdo ukradl přesně 123.5k Sats~~ (FIXED)
  * ~~hodnoty v normálu a možná i za pozitivních nebo negativních dopadech nemají ten formát 123.4k, například že reward je 50 000 000 nebo kolik nebo že difficulty je 1234567~~ (FIXED)
  * ~~nemám jak ověřit, jestli ty pozitivní nebo negativní dopady opravdu způsobují změny ve hře, viz předchozí 2 body v news floating~~ (FIXED)
  * ~~obecně bych bral, aby dopad trval déle, nyní je to třeba desitky sekund, aby bylo by fajn, kdyby trval třeba jednotky minut a zároveň se prodloužila o něco doba, kdy dopady přiskakují, klidně i nějaký random, nemusí to nutně přicházet vždy po statickém časovém intervalu~~ (FIXED)
  * ~~stejně tak by se mohla prodloužit doba, kdy je trh stabilní~~ (FIXED)
* Stash tab
  * ~~po hodně klikání na bedny, když nemám dostatek čipu, se zafrontuje toast hláška, že nemám čipy, takže to tam pak skáče i několik sekund pořád dokola, chtěl by to přidat ochranu, že se to nefrontuje, pokud je ta hláška zrovna aktivní~~ (FIXED)

# Improvements

* nákup HW by mohl probíhat tak, že při dlouhém stisku se nakoupí maximální možný počet za aktuální stav balance, doprovázeno hezkým UI efektem, třeba že kolem tlačítka bude postupně dokola nabíhat 
border a jak se zaplní, tak se to nakoupí, aby se dalo rozlišit mezi tapem = jeden nákup jedno zařízení, dlouhý stisk, kupuju kolik, na kolik mám nebo ještě lepší, dlouhé stisk začně autonakupovat a bude tam takový ten exponeniální efekt, že držím 2 sekundy, nakupuje se pomalu, čím déle držím, tím rychleji se nakupuje
* název hry, teď se mi ukazuje crypto_miner_tycoon, chci BTC Only Tycoon
* ikona hry, teď je tam nějaká generická
* ikonka pro settings, to kolečko se mi nelíbí a je tam tak zapadlé v rohu
  * například ikonka hexagonu, kde uvnitř budou 3 horizontální šoupátka
* stash nemá UI efekt, že se odemkne bedna a co ta bedna odemknula
* přepínání mezi USD a BTC by mohlo také vyvolat toast notifikaci, jako je to u tabu MINE

# New Feature

* achievements / milestones
  * One-time rewards for achieving goals (e.g. 1000 ASICs = 50 Chips).
* notifikace do mobilu
