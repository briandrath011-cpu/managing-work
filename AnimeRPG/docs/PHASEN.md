# Entwicklungsphasen – Scripts, Remotes, Tests und Fehlerquellen

Jede Phase listet: **Script → Typ → Explorer-Ort**, benötigte **Remotes** und **Ordner**, **Test**-Anleitung,
**mögliche Fehler** und **Plattform**-Hinweise. Der vollständige Code steht in der jeweiligen Datei unter `src/`.

Legende: **S** = Script, **LS** = LocalScript, **MS** = ModuleScript.
`RS` = ReplicatedStorage, `SSS` = ServerScriptService, `SPS` = StarterPlayer.StarterPlayerScripts.

## Alle Remotes (werden automatisch erstellt)

`RS.Modules.Shared.Net` legt beim Serverstart alles in `ReplicatedStorage.Remotes` an – nichts muss von Hand
erstellt werden. Jeder Server-Handler prüft Typen, Wertebereiche, Cooldowns und Rate-Limits.

| Name            | Typ            | Richtung        | Zweck |
|-----------------|----------------|-----------------|-------|
| DataSync        | RemoteEvent    | Server → Client | Speicherstand (voll / einzelne Schlüssel) |
| Notify          | RemoteEvent    | Server → Client | Meldungen, Server-Nachrichten |
| FX              | RemoteEvent    | Server → Client | Effekte, Sounds, Animationen |
| ClientMotion    | RemoteEvent    | Server → Client | Knockback, Dash, Freeze, Ragdoll, Downed |
| BossUI          | RemoteEvent    | Server → Client | Boss-Intro, Lebensbalken, Phasen |
| DialogOpen      | RemoteEvent    | Server → Client | NPC-Dialog |
| InstanceState   | RemoteEvent    | Server → Client | Dungeon-/Raid-Lobby, Räume, Timer |
| SpinReveal      | RemoteEvent    | Server → Client | Mythic/Secret-Ankündigung |
| CombatAction    | RemoteEvent    | Client → Server | M1, Heavy, Block, Konter, Dash |
| UseSkill        | RemoteEvent    | Client → Server | Power-/Waffen-Skill + Zielposition |
| Transform       | RemoteEvent    | Client → Server | Transformation aktivieren |
| MovementState   | RemoteEvent    | Client → Server | Flug/Wandlauf (für Anti-Cheat) |
| GetData         | RemoteFunction | Client → Server | Speicherstand nachladen |
| RequestStart    | RemoteFunction | Client → Server | „Start Game“ – Charakter spawnen |
| StatAction      | RemoteFunction | Client → Server | Statpunkte verteilen / zurücksetzen |
| Spin            | RemoteFunction | Client → Server | 1x / 10x Spin |
| PowerAction     | RemoteFunction | Client → Server | Power ausrüsten/sperren/löschen, Lager erweitern |
| InventoryAction | RemoteFunction | Client → Server | Ausrüsten, benutzen, sperren, favorisieren, löschen |
| QuestAction     | RemoteFunction | Client → Server | Annehmen, abgeben, abbrechen |
| CraftAction     | RemoteFunction | Client → Server | Craften |
| TraitAction     | RemoteFunction | Client → Server | Trait würfeln |
| ProfileAction   | RemoteFunction | Client → Server | Titel, Einstellungen, Transformation wählen |
| ShopAction      | RemoteFunction | Client → Server | Kaufen, verkaufen, Kampfstil, Training |
| FastTravel      | RemoteFunction | Client → Server | Schnellreise |
| DungeonAction   | RemoteFunction | Client → Server | Dungeon-Lobby |
| RaidAction      | RemoteFunction | Client → Server | Raid-Lobby |

## Benötigte Ordner

In `default.project.json` definiert (bei manueller Einrichtung selbst anlegen):
`Workspace/Map, NPCs, Enemies, Bosses, Interactables, Effects, Drops` ·
`ReplicatedStorage/Remotes` · `ReplicatedStorage/Assets/VFX, Sounds, Animations, Weapons, Rigs`.
Alle weiteren Ordner (z. B. `Workspace.NPCs.Summons`, `ServerStorage.RigCache`) erstellt der Code selbst.

---

## PHASE 1 – Player Data + Level + EXP + Stats

| Script | Typ | Ort |
|---|---|---|
| Main | S | SSS.Main |
| PlayerDataService | MS | SSS.Services |
| CharacterService | MS | SSS.Services |
| Registry, RateLimiter, Validate, EntityRegistry | MS | SSS.ServerModules |
| GameConfig, Progression, DataTemplate | MS | RS.Modules.Config |
| Net, Signal, TableUtil | MS | RS.Modules.Shared |
| DataController | MS | SPS.Controllers |
| Stats (Tab) | MS | SPS.UI.Tabs |

**Remotes:** DataSync, GetData, StatAction, RequestStart, Notify.
**Funktionen:** DataStore mit Session-Lock (verhindert Duplikate über Server hinweg), Retries mit Backoff,
Autosave (120 s), `BindToClose`, Reparatur beschädigter Saves, Level-Ups (3 Statpunkte/Level, Spin alle 5,
Gems alle 10 Level), MaxHP aus Level + Defense, Energie aus Energy, Tempo aus Agility.
**Test:** Play → `/exp 5000` → Level-Up-Banner. Menü (M) → Stats → Punkte verteilen → Werte rechts ändern sich.
Stop/Play → Level bleibt (nur mit API-Zugriff).
**Mögliche Fehler:** „MEMORY mode“ im Output → API-Zugriff in Game Settings aktivieren.
„Your data could not be loaded“ → DataStore-Ausfall, Spieler neu verbinden lassen.
**Plattform:** komplett serverseitig; Stats-Tab ist mit Maus, Touch und Controller bedienbar.

## PHASE 2 – Movement

| Script | Typ | Ort |
|---|---|---|
| MovementController | MS | SPS.Controllers |
| InputController | MS | SPS.Controllers |
| InputConfig | MS | RS.Modules.Config |
| MovementValidator | MS | SSS.Services |
| Motion | MS | SSS.ServerModules |

**Remotes:** MovementState, ClientMotion, CombatAction („Dash“).
**Funktionen:** Sprint, Dash (vor/seitlich/zurück/Luft), Doppelsprung, Luft-Dash, Wandsprung, Wandlauf,
Flug (ab Level 110 mit „Wings of Freedom“). Server prüft Geschwindigkeit und setzt bei Cheats zurück.
**Test:** Shift halten, Q in verschiedene Richtungen, in der Luft Leertaste, sprintend an Wände springen.
`/level 110` + `/item WingsOfFreedom 1` → Inventar → Benutzen → H.
**Mögliche Fehler:** Rubber-Banding bei extrem hohem Ping → `GameConfig.Movement.SpeedTolerance` erhöhen.
**Plattform:** Controller B/L3/Y, Mobile-Buttons RUN/DASH + Standard-Sprungtaste.

## PHASE 3 – M1 Combat + Block + Dash

| Script | Typ | Ort |
|---|---|---|
| CombatServer | MS | SSS.Services |
| CombatController | MS | SPS.Controllers |
| AnimationLib | MS | SPS.ClientModules |
| FightingStyles | MS | RS.Modules.Combat |

**Remotes:** CombatAction (M1, Heavy, BlockStart, BlockEnd, Counter, Dash).
**Funktionen:** 4er-Combo mit Finisher, Launcher (4. Treffer + Sprung halten), Downslam (4. Treffer in der Luft),
Luft-Combos, Heavy/Guard Break, Block mit Guard-Leiste, Perfect Block (0,22 s Fenster, betäubt Angreifer),
Konter (Block + Heavy), I-Frames beim Dash.
**Test:** Wölfe westlich des Dorfs angreifen; Bandit-Angriff genau vor dem Treffer blocken → „PERFECT“.
**Mögliche Fehler:** keine Animationen → normal, prozedurale Posen sind aktiv; eigene IDs in `AssetIds` eintragen.
**Plattform:** RT/RB/LT am Controller, ATTACK/HEAVY/BLOCK auf Mobile (ATTACK gedrückt halten = Auto-Combo).

## PHASE 4 – Damage + Hitboxes

| Script | Typ | Ort |
|---|---|---|
| DamageService | MS | SSS.Services |
| Hitbox | MS | SSS.ServerModules |
| DamageFormula, Modifiers | MS | RS.Modules.Combat |
| FXService | MS | SSS.Services |
| VFXController | MS | SPS.Controllers |

**Remotes:** FX.
**Formel:** Basis × Stat-Skalierung × Waffen/Power-Multiplikator (inkl. Mastery) × Buffs × Krit × Level-Faktor ×
Defense-Faktor (100/(100+Def)) × Block. Treffer-Feedback: Funken, Schadenszahl, Hitstop, Kamerawackeln,
bei starken Treffern Shockwave, Bodenrisse, Screen-Flash, Impact-Frame.
**Test:** `python3 tools/run_tests.py` (DamageFormula-Tests); im Spiel Krit-Zahlen (gelb, „!“) beobachten.
**Mögliche Fehler:** Treffer „fehlen“ bei hohem Ping → Hitboxen sind serverseitig, Toleranz in
`GameConfig.Combat.HitRangeTolerance`.

## PHASE 5 – Power Framework

| Script | Typ | Ort |
|---|---|---|
| PowerService | MS | SSS.Services |
| SkillContext | MS | SSS.ServerModules |
| PowerRegistry | MS | RS.Modules.Powers |
| AbilityController | MS | SPS.Controllers |

**Remotes:** UseSkill, PowerAction.
**Funktionen:** Jede Power = eigenes ModuleScript mit 3 Skills + Ultimate, Passive, Mastery-Freischaltung
(0/15/35/75), Cooldowns (inkl. Cooldown-Reduktion), Energiekosten, Hitboxen, Stun, Knockback, Guard-Schaden.
Skills nutzen nur die sichere `ctx`-API (HitRadius, Projectile, Dash, Buff, Summon, Counter, FX …).
**Test:** `/spins 20` → Spin → Power ausrüsten → Taste 1; `/mastery 100` → alle 4 Slots frei.
**Mögliche Fehler:** „Requires mastery X“ → Mastery erst verdienen (Skills benutzen, Gegner besiegen, Trainer).

## PHASE 6 – Erste Powers

`RS.Modules.Powers.List`: **Rinnegan, TimeStand, Limitless, ShadowMonarch, SaiyanPower, RubberPower, Sharingan,
Blaze, Gale, Frost, VoidEmperor** (je MS). Seltenheiten: Common (Blaze, Gale), Rare (Rubber, Frost),
Epic (Sharingan, Saiyan), Legendary (Time Stand, Shadow Monarch), Mythic (Limitless, Rinnegan), Secret (Void Emperor).
**Test:** `/power Rinnegan` (oder jede andere ID) + `/mastery 100` → Tasten 1–4 ausprobieren.
**Plattform:** Konsole/Mobile zielen automatisch auf den nächsten Gegner vor dir (oder Lock-On).

## PHASE 7 – Power Spins

| Script | Typ | Ort |
|---|---|---|
| SpinService | MS | SSS.Services |
| SpinLogic | MS | RS.Modules.Powers |
| RarityConfig | MS | RS.Modules.Config |
| SpinMenu | MS | SPS.UI (ScreenGui „SpinMenu“) |
| Powers (Tab) | MS | SPS.UI.Tabs |

**Remotes:** Spin, SpinReveal, PowerAction.
**Funktionen:** Zentrale Chancen (45/28/15/8/3/1 %), Pity (Legendary 40, Mythic 120, Secret 400 Spins – serverseitig
gespeichert), 1x/10x, Gems-Kauf, Walzen-Animation, Skip, 10x-Kartenaufdeckung, Mythic-/Secret-Reveal,
Auto-Umwandeln von Common/Rare in Gold, Power-Lager mit Ausbau.
**Test:** `/spins 50` → P → SPIN x10. Pity-Anzeige steigt; Test „Pity“ in `tests/SpinLogic.spec.luau`.
**Mögliche Fehler:** „Power storage full“ → Powers löschen oder Lager erweitern.

## PHASE 8 – Weapons

| Script | Typ | Ort |
|---|---|---|
| WeaponService | MS | SSS.Services |
| WeaponVisual | MS | SSS.ServerModules |
| WeaponClasses, WeaponCatalog, WeaponSkills | MS | RS.Modules.Weapons |

**Klassen:** Katana, Greatsword, Dagger, Scythe, Spear, Gauntlets, Staff, Dual Blades (Schaden, Tempo, Reichweite,
Seltenheit, Mastery, Passive, Skills). **Seltene Waffen:** Night Slayer (Shadow Crescent / Nightfall Slash),
Dragon Fang, Moon Katana, Demon Scythe, Thunder Spear, Celestial Blade, Void Greatsword, Void Katana.
Waffenmodelle werden aus Parts gebaut (eigene Modelle über `RS.Assets.Weapons`).
**Test:** `/item NightSlayer 1` → Menü → Weapons → Equip.

## PHASE 9 – Weapon Mastery

Gespeichert pro Waffen-ID in `PlayerData.WeaponMastery`. Mastery 0 = M1, 20 = Skill Z, 50 = Skill X,
100 = Ultimate C. EXP durch Treffer, Skills, Kills und den Weapon Master (Greenwood).
**Test:** Menü → Weapons zeigt Balken + freigeschaltete Skills; `/mastery 100`.

## PHASE 10 – Inventory

| Script | Typ | Ort |
|---|---|---|
| InventoryService | MS | SSS.Services |
| ItemCatalog, ItemUtil, Recipes | MS | RS.Modules.Items |
| Inventory (Tab) | MS | SPS.UI.Tabs |

**Remotes:** InventoryAction.
**Funktionen:** Kategorien (Waffen, Rüstung, Accessoires, Materialien, Verbrauchsgüter, Kosmetik), Suche,
Sortierung (Seltenheit/Name/Neu/Menge), Equip/Unequip, Benutzen, Sperren, Favorit, Löschen.
Slots: Weapon, Armor, Head, Accessory 1, Accessory 2 – alle verändern Stats.
**Test:** Menü → Inventory → Heiltrank benutzen; Item sperren → Löschen wird verweigert.

## PHASE 11 – NPCs + Enemies

| Script | Typ | Ort |
|---|---|---|
| EnemyService | MS | SSS.Services |
| NPCService | MS | SSS.Services |
| AIBrain, NPCRig, NPCAnimator | MS | SSS.ServerModules |
| EnemyCatalog, EnemySkills | MS | RS.Modules.Enemies |
| NPCCatalog | MS | RS.Modules.NPCs |

**KI:** erkennt Spieler, verfolgt, M1-Combos, blockt/weicht aus wenn angegriffen, Skills nach Distanz,
Rückzug bei wenig HP, kehrt nach Hause zurück. Eine einzige KI-Schleife für alle NPCs; NPCs weit weg von
Spielern schlafen (Performance).
**Test:** Wölfe/Banditen spawnen in Greenwood; Banditen blocken manchmal Angriffe.
**Mögliche Fehler:** „R15 creation failed“ → Fallback auf R6-Rig (funktioniert trotzdem).

## PHASE 12 – Quest System

| Script | Typ | Ort |
|---|---|---|
| QuestService | MS | SSS.Services |
| QuestCatalog, QuestLogic | MS | RS.Modules.Quests |
| DialogUI | MS | SPS.UI (ScreenGui „QuestUI“) |
| Quests (Tab) | MS | SPS.UI.Tabs |

**Remotes:** DialogOpen, QuestAction.
**Typen:** Kill, Boss, Collect, Delivery, Exploration, Dungeon, Daily (3 pro Tag), Weekly (2 pro Woche),
Secret (versteckter Einsiedler in der Höhle). NPCs zeigen „!“ (Quest verfügbar) bzw. „?“ (abgeben).
**Test:** Captain Lyra (Greenwood) ansprechen (E) → Quest annehmen → Wölfe besiegen → zurück → abgeben.

## PHASE 13 – Boss System

| Script | Typ | Ort |
|---|---|---|
| BossService | MS | SSS.Services |
| BossCatalog, BossSkills | MS | RS.Modules.Bosses |
| BossUI | MS | SPS.UI (ScreenGui „BossUI“) |

**Remotes:** BossUI.
**Funktionen:** Intro mit Kameraschwenk, großer Lebensbalken, Phasen (100–70 / 70–30 / < 30 % Enrage mit Aura,
mehr Tempo, Ultimate), Distanz halten, Dash, Combos, AoE mit Warnkreisen, Konterhaltung, Respawn-Timer.
Bosse: Bandit Chief, Sand Pharaoh, Thunder Tyrant, Frost Empress, Demon Lord, Celestial Sovereign,
Midnight Wraith (nur nachts), Ruin Colossus (World Boss), 5 Dungeon-Bosse, Eclipse Tyrant (Raid).
**Test:** `/boss BanditChief` oder zur Arena nordöstlich des Dorfes laufen.

## PHASE 14 – Drops

| Script | Typ | Ort |
|---|---|---|
| DropService | MS | SSS.Services |

Persönlicher Loot für jeden Beteiligten (≥ 10 % Schaden, bei Bossen ≥ 3 %), Luck erhöht Chancen,
EXP/Gold mit Boni, Mastery, Boss-Sammellog, Titel. Seltene Drops: Lichtsäule + Orb; Mythic+ wird serverweit angekündigt.
**Test:** `/boss MidnightWraith` mehrmals besiegen → Night Slayer (10 %).

## PHASE 15 – Erste vollständige Region

| Script | Typ | Ort |
|---|---|---|
| WorldBuilder | MS | SSS.Services |
| ExplorationService | MS | SSS.Services |
| WorldConfig | MS | RS.Modules.World |
| EnvironmentService | MS | SSS.Services |
| WeatherController | MS | SPS.Controllers |

Greenwood Village komplett (Dorf, Wald, Banditenlager, Boss-Arena, Höhle, Parkour-Turm, Friedhof, NPCs,
Truhen, Wegpunkte, Dungeon-Tor) – dazu Desert Kingdom, Sky Islands, Frozen Empire, Demon Realm, Celestial Realm
mit Wegen, Portalen (levelgesperrt), Geheimorten, Nachtpflanzen. Tag/Nacht (Morning/Day/Evening/Night),
Wetter (Rain/Storm/Snow/Fog/Clear).
**Test:** Output zeigt „World built in …s“. `/tp Desert`, `/time 21`, `/weather Storm`.

## PHASE 16 – Dungeons

| Script | Typ | Ort |
|---|---|---|
| DungeonService | MS | SSS.Services |
| Dungeons | MS | RS.Modules.World |
| InstanceUI | MS | SPS.UI (ScreenGui „DungeonUI“) |

**Remotes:** DungeonAction, InstanceState.
Lobby → Raum 1 (Wellen) → Raum 2 (Elite) → Raum 3 (Miniboss) → Endraum (Boss) → Belohnungstruhe.
1–4 Spieler, Normal / Hard / Nightmare, Zeitlimit, Wiederbelebung am Raum-Checkpoint.
**Test:** `/level 10` → Tor beim Dungeon Keeper (E) → Create Party → „Start Now“.

## PHASE 17 – Crafting

| Script | Typ | Ort |
|---|---|---|
| CraftingService | MS | SSS.Services |
| Recipes | MS | RS.Modules.Items |

**Remotes:** CraftAction. Crafter in jeder Region (z. B. Void Katana = 5 Demon Horn + 3 Void Crystal + 1 Boss Core
beim Hellforger).
**Test:** `/item DemonHorn 5`, `/item VoidCrystal 3`, `/item BossCore 1`, `/gold 60000`, `/tp Demon` → Hellforger.

## PHASE 18 – Transformations

| Script | Typ | Ort |
|---|---|---|
| TransformationService | MS | SSS.Services |
| Transformations | MS | RS.Modules.Progression |

**Remotes:** Transform, ProfileAction („EquipTransformation“).
Awakening-Leiste lädt durch Schaden verursachen/erhalten und Combos. Aktivieren: Aura, Shockwave, Kamera-Effekt,
Werte-Boni, schnellere Cooldowns. Awakening ab Level 25, weitere durch seltene Boss-Items.
**Test:** `/level 25`, `/awaken`, G.

## PHASE 19 – World Events

| Script | Typ | Ort |
|---|---|---|
| WorldEventService | MS | SSS.Services |
| WorldEvents | MS | RS.Modules.World |

Meteor, Demon Invasion, World Boss, Portal, Treasure, Blood Moon (nur nachts), Thunder Storm – mit
Server-Nachricht („⚠ A mysterious portal has appeared!“) und Belohnungen für Teilnehmer.
**Test:** `/event Portal`, `/event BloodMoon` (nachts: `/time 22`).

## PHASE 20 – Raids + Endgame

| Script | Typ | Ort |
|---|---|---|
| RaidService | MS | SSS.Services |
| Raids | MS | RS.Modules.World |
| AchievementService | MS | SSS.Services |

**Remotes:** RaidAction, InstanceState.
Eclipse Raid (bis 8 Spieler): Schild-Mechanik (Kristalle zerstören), Eclipse-Mechanik (in Lichtkreise stellen),
Wiederbelebung (E halten), Wipe-Erkennung, seltene Drops. Endgame: Raids, World Bosses, Mythic-Waffen,
Secret-Power, Nightmare-Dungeons, Crafting, Titel, Achievements, Mastery, Kosmetik.
**Test:** `/level 200`, `/tp Celestial` → Raid Herald → Tor.

## PHASE 21 – UI Polish + VFX + Sound

| Script | Typ | Ort |
|---|---|---|
| ClientMain | LS | SPS |
| UIKit, VFXLib, SoundLib, Platform | MS | SPS.ClientModules |
| HUD, Menu, MainMenu | MS | SPS.UI |
| Tabs (10) | MS | SPS.UI.Tabs |
| CameraController, AudioController, SettingsController | MS | SPS.Controllers |
| AssetIds | MS | RS.Modules.Assets |

Ladebildschirm → Titel → Play/Character/Settings → Start Game. HUD mit Leben, Energie, EXP, Level, Power, Waffe,
Awakening, Quest-Tracker, Skill-Slots (Controller-Symbole automatisch, Touch-Buttons auf Mobile).
Musik wechselt pro Region, Boss, Dungeon und Raid.

## PHASE 22 – Performance + Anti-Exploit + Balancing

| Script | Typ | Ort |
|---|---|---|
| AntiExploitService | MS | SSS.Services |
| MovementValidator | MS | SSS.Services |
| RateLimiter, Validate | MS | SSS.ServerModules |
| QualityConfig | MS | RS.Modules.Config |
| ObjectPool, Maid | MS | RS.Modules.Shared |

**Performance:** StreamingEnabled, eine KI-Schleife, schlafende NPCs, Rig-Templates werden geklont,
Object Pooling (Schadenszahlen, Sounds), Effekt-Limit, Distanz-Culling, Qualitätsstufen Low/Medium/High
(Mobile automatisch Low), automatische Aufräumung aller Effekte.
**Anti-Exploit:** Server prüft Schaden, Reichweite (serverseitige Hitboxen), Cooldowns, Bewegung, Spins, Drops,
Währung, Quest-Belohnungen; Rate-Limits auf jedem Remote; Strikes mit Verfall, Kick erst bei klaren Verstößen.
**Balancing:** alle Zahlen in `GameConfig`, `RarityConfig`, `Progression`, `EnemyService:HealthFor/DamageFor`.

---

## Häufige Fehler und Lösungen

| Meldung / Problem | Ursache | Lösung |
|---|---|---|
| `[PlayerData] … MEMORY mode` | Kein API-Zugriff in Studio | Game Settings → Security → API Services aktivieren |
| `Infinite yield possible on ReplicatedStorage:WaitForChild("Remotes")` | Server-Script fehlt/fehlerhaft | Prüfen, ob `SSS.Main` ein **Script** ist und alle Services vorhanden sind |
| `[Main] Missing service module: X` | ModuleScript fehlt oder falsch benannt | Datei/Objekt mit exakt diesem Namen in `SSS.Services` anlegen |
| Spieler spawnt nicht | `RequestStart` nicht aufgerufen | Im Titelbildschirm **PLAY → START GAME** drücken |
| Keine Musik / wenige Sounds | Platzhalter-IDs sind leer | IDs in `AssetIds` eintragen |
| Keine Animationen, nur Posen | Animations-IDs leer | R15-Animationen veröffentlichen und eintragen |
| Gegner laufen ohne Animation | Standard-Animations-IDs nicht ladbar | `AssetIds.NPCAnimations` durch eigene ersetzen |
| Charakter wird zurückgesetzt | MovementValidator (zu hohe Geschwindigkeit) | Nur bei Cheats; sonst Toleranz in `GameConfig.Movement` erhöhen |
| Test-Befehle wirken nicht | Nur in Studio aktiv | Eigene UserId in `GameConfig.Debug.AdminUserIds` eintragen |
