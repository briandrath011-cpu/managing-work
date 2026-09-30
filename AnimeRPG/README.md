# Ascendant Realms – Roblox Anime Action RPG

Ein vollständiges, erweiterbares Anime-Action-RPG für Roblox (PC, Konsole und Mobile).
Alle Systeme sind eigenständig entwickelt: eigene Welt, eigene UI, eigene Effekte, keine kopierten Assets.

- **~130 Luau-Dateien** in sauberen ModuleScripts, getrennt in Server / Client / Shared
- **Serverautorität:** Schaden, Drops, Spins, Level, Währung und Inventar entscheidet nur der Server
- **Keine externen Assets nötig:** Welt, Waffen, NPCs und Effekte werden per Code gebaut; Animationen haben prozedurale Fallbacks
- **Getestet:** 65 Unit-Tests (Schaden, Pity, Level, Quests, Content-Querverweise) + Lint + Typanalyse

Die Detail-Dokumentation pro Entwicklungsphase (Scripts, Explorer-Orte, Remotes, Tests, Fehlerquellen) steht in
**[docs/PHASEN.md](docs/PHASEN.md)**.

---

## 1. Installation

### Variante A – Rojo (empfohlen)

1. [Rojo 7](https://rojo.space) installieren (CLI + Studio-Plugin).
2. Im Ordner `AnimeRPG/`:
   ```bash
   rojo build -o AnimeRPG.rbxl      # erzeugt die fertige Place-Datei
   # oder live synchronisieren:
   rojo serve                        # dann im Studio-Plugin "Connect"
   ```
3. `AnimeRPG.rbxl` in Roblox Studio öffnen.

### Variante B – manuell im Explorer

Jede Datei entspricht einem Objekt im Explorer:

| Dateiendung        | Objekt in Studio |
|--------------------|------------------|
| `Name.server.luau` | **Script**       |
| `Name.client.luau` | **LocalScript**  |
| `Name.luau`        | **ModuleScript** |
| Ordner             | **Folder**       |

Der Pfad der Datei ist der Explorer-Pfad, z. B.
`src/ServerScriptService/Services/PlayerDataService.luau` →
`ServerScriptService > Services > PlayerDataService (ModuleScript)`.
Zusätzlich die Ordner aus `default.project.json` anlegen (Workspace: `Map`, `NPCs`, `Enemies`, `Bosses`,
`Interactables`, `Effects`, `Drops`; ReplicatedStorage: `Remotes`, `Assets/…`) und
`Players.CharacterAutoLoads = false`, `Workspace.StreamingEnabled = true` setzen.

### Wichtige Studio-Einstellungen

- **Game Settings → Security → Enable Studio Access to API Services** einschalten,
  sonst läuft der DataStore im Speicher-Modus (Warnung im Output, nichts wird gespeichert).
- Das Spiel muss einmal veröffentlicht sein, damit DataStores funktionieren.

---

## 2. Steuerung

| Aktion              | PC               | Controller          | Mobile              |
|---------------------|------------------|---------------------|---------------------|
| Angriff (M1-Combo)  | Linksklick       | RT                  | ATTACK              |
| Heavy / Guard Break | R                | RB                  | HEAVY               |
| Blocken (halten)    | F                | LT                  | BLOCK               |
| Konter              | F + R            | LT + RB             | BLOCK + HEAVY       |
| Dash (vor/seit/zurück/Luft) | Q        | B                   | DASH                |
| Sprinten            | Shift            | L3 (Umschalten)     | RUN                 |
| Power-Skills 1–4    | 1 2 3 4          | D-Pad ↑ → ↓ ←       | Skill-Slots antippen|
| Waffen-Skills       | Z X C            | LB + X / Y / B      | Skill-Slots antippen|
| Transformation      | G                | LB + RS             | AWAKEN              |
| Lock-On             | T                | RS                  | LOCK                |
| Fliegen (freigeschaltet) | H           | Y                   | –                   |
| Menü                | M                | View / Select       | ☰ Menu              |
| Karte               | N                | über Menü           | 🗺 Map              |
| Spin-Menü           | P                | über Menü           | ✦ Spin              |
| Interagieren        | E                | X                   | Prompt antippen     |
| Launcher            | 4. Treffer + Leertaste halten | 4. Treffer + A halten | – |
| Doppelsprung / Wandsprung / Wandlauf | Leertaste in der Luft / an Wand / Sprinten an Wand | A | Sprung |

Die HUD-Tasten wechseln automatisch zwischen Tastatur- und Controller-Symbolen,
sobald ein anderes Eingabegerät benutzt wird. Auf Handys erscheinen Touch-Buttons.

---

## 3. Projektstruktur (Explorer)

```
ReplicatedStorage
├── Modules              (geteilte ModuleScripts – Client + Server)
│   ├── Config           GameConfig, RarityConfig, Progression, DataTemplate, InputConfig, QualityConfig
│   ├── Shared           Net (alle Remotes), Signal, Maid, ObjectPool, TableUtil, WeightedRandom, Format
│   ├── Combat           DamageFormula, Modifiers, FightingStyles
│   ├── Powers           PowerRegistry, SpinLogic, List/<eine Datei pro Power>
│   ├── Weapons          WeaponClasses, WeaponCatalog, WeaponSkills
│   ├── Items            ItemCatalog, ItemUtil, Recipes
│   ├── Enemies          EnemyCatalog, EnemySkills
│   ├── Bosses           BossCatalog, BossSkills
│   ├── NPCs             NPCCatalog
│   ├── Quests           QuestCatalog, QuestLogic
│   ├── World            WorldConfig, Dungeons, Raids, WorldEvents
│   ├── Progression      Traits, Titles, Transformations, Achievements
│   └── Assets           AssetIds (alle Animation-/Sound-/Musik-IDs)
├── Remotes              (wird beim Serverstart mit allen RemoteEvents/Functions gefüllt)
└── Assets               VFX, Sounds, Animations, Weapons, Rigs (für eigene Modelle)

ServerScriptService
├── Main                 (Script – startet alle Services)
├── Services             (29 ModuleScripts, z. B. PlayerDataService, CombatServer, PowerService,
│                         SpinService, WeaponService, QuestService, BossService, DungeonService, DropService …)
└── ServerModules        Registry, EntityRegistry, SkillContext, Hitbox, Motion, AIBrain, NPCRig,
                         NPCAnimator, WeaponVisual, RateLimiter, Validate

StarterPlayer
├── StarterPlayerScripts
│   ├── ClientMain       (LocalScript – startet Controller + UI)
│   ├── Controllers      DataController, InputController, MovementController, CombatController,
│   │                    AbilityController, CameraController, VFXController, AudioController,
│   │                    WeatherController, SettingsController
│   ├── ClientModules    UIKit, VFXLib, SoundLib, AnimationLib, Platform, ClientRegistry
│   └── UI               MainMenu, HUD, Menu (+ Tabs), SpinMenu, BossUI, DialogUI, InstanceUI
└── StarterCharacterScripts
    └── Health           (leeres Script – ersetzt die Standard-Regeneration)

StarterGui               (bleibt leer – alle ScreenGuis werden per Code erzeugt:
                          HUD, Menu, SpinMenu, QuestUI, BossUI, DungeonUI, MainMenu)

Workspace
├── Map                  (wird vom WorldBuilder gebaut)
├── NPCs / Enemies / Bosses / Interactables / Effects / Drops
```

---

## 4. Testen im Studio

1. **Play** drücken → Ladebildschirm → Titelbildschirm → **PLAY** → **START GAME**.
2. Test-Befehle im Chat (nur in Studio aktiv, siehe `DevCommandService`):

| Befehl                  | Wirkung                                         |
|-------------------------|-------------------------------------------------|
| `/level 50`             | auf Level 50 springen                           |
| `/gold 100000` `/gems 500` `/spins 20` | Währungen                        |
| `/item NightSlayer 1`   | Item geben (IDs siehe Catalogs)                 |
| `/power Limitless`      | Power ins Lager legen und ausrüsten             |
| `/mastery 100`          | Power- und Waffen-Mastery maximieren            |
| `/stats`                | +100 Statpunkte                                 |
| `/awaken`               | Awakening-Leiste füllen                         |
| `/boss BanditChief`     | Boss vor dir spawnen                            |
| `/event Portal`         | Welt-Event starten (Meteor, DemonInvasion, WorldBoss, Portal, Treasure, BloodMoon, ThunderStorm) |
| `/time 21`              | Uhrzeit setzen (Nacht ab 20 Uhr)                |
| `/weather Storm`        | Wetter setzen                                   |
| `/tp Desert`            | in eine Region teleportieren                    |
| `/unlockall`            | alle Wegpunkte + Flug freischalten              |
| `/heal`                 | volle Gesundheit und Energie                    |

3. Mehrspieler testen: **Test → Clients and Servers → 2 Players → Start**.
4. Mobile/Konsole testen: **Test → Device** (Emulator) bzw. Controller anschließen.

### Offline-Tests (ohne Studio)

```bash
# benötigt das luau-Binary: https://github.com/luau-lang/luau/releases
python3 tools/run_tests.py          # oder: LUAU_BIN=/pfad/zu/luau python3 tools/run_tests.py
selene src                          # Lint (Konfiguration: selene.toml + roblox_lite.yml)
stylua --check src tests            # Formatierung
```

---

## 5. Eigene Assets einsetzen

Alle IDs stehen in **`ReplicatedStorage.Modules.Assets.AssetIds`**:

- **Animationen** (`AssetIds.Animations`): R15-Animation im Animation Editor erstellen → *Publish to Roblox* →
  ID als `"rbxassetid://123…"` bei `Id` eintragen. Leere ID = prozedurale Pose (`Fallback`).
- **Sounds** (`AssetIds.Sounds`) und **Musik** (`AssetIds.Music`): Audio hochladen → ID eintragen.
  Musik wechselt automatisch pro Region, Boss, Dungeon und Raid.
- **Eigene Waffenmodelle:** Model mit Part `Handle` in `ReplicatedStorage.Assets.Weapons` legen,
  Name = Waffen-ID (z. B. `NightSlayer`).
- **Eigene Gegner-/NPC-Modelle:** Model mit `Humanoid` + `HumanoidRootPart` in `ReplicatedStorage.Assets.Rigs`,
  Name = Gegner-/NPC-ID.
- **Eigene Karte:** `GameConfig.World.AutoBuild = false` setzen und die Karte in `Workspace.Map` bauen.
  Positionen (Spawns, NPCs, Bosse, Wegpunkte) in `WorldConfig` anpassen.

---

## 6. Erweitern

| Neues …        | So geht's |
|----------------|-----------|
| **Power**      | `Powers/List/Blaze.luau` kopieren, `Id`, `DisplayName`, `Rarity` und die 4 Skills ändern. Wird automatisch im Spin-Pool registriert. |
| **Waffe**      | Eintrag in `WeaponCatalog` (Klasse, Schaden, Passive, optionale eigene Skills aus `WeaponSkills`). |
| **Gegner**     | Eintrag in `EnemyCatalog` + Spawner in `WorldConfig.EnemySpawns`. |
| **Boss**       | Eintrag in `BossCatalog` (Phasen, Ultimate, Drops) + Arena in `WorldConfig.Bosses`. |
| **Quest**      | Eintrag in `QuestCatalog` + Quest-ID beim NPC in `NPCCatalog`. |
| **Item/Rezept**| `ItemCatalog` / `Recipes`. |
| **Region**     | `WorldConfig.Regions` + Bau-Funktion im `WorldBuilder`. |

Nach Änderungen `python3 tools/run_tests.py` ausführen – der Integritätstest findet falsche IDs sofort.

---

## 7. Hinweis zu Namen

Einige Power-Namen (z. B. Rinnegan, Sharingan) wurden wie gewünscht übernommen. Vor einer öffentlichen
Veröffentlichung empfiehlt es sich, markenrechtlich geschützte Anime-Begriffe umzubenennen – dafür reicht es,
`DisplayName` in der jeweiligen Datei unter `Powers/List` zu ändern (die interne `Id` darf bleiben).
