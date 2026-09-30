# StarterGui

All screens are built in code by the client UI modules
(`StarterPlayer/StarterPlayerScripts/UI`) so they can adapt to PC, console and mobile.
At runtime these ScreenGuis appear in `PlayerGui`:

| ScreenGui  | Module                | Purpose                                   |
|------------|-----------------------|-------------------------------------------|
| MainMenu   | UI/MainMenu.luau      | Loading screen, title screen, start game  |
| HUD        | UI/HUD.luau           | Bars, ability slots, quest tracker, touch |
| Menu       | UI/Menu.luau + Tabs   | Character, Inventory, Powers, ... , Map   |
| Inventory  | UI/Tabs/Inventory     | (tab inside Menu)                         |
| SpinMenu   | UI/SpinMenu.luau      | Power spins                               |
| QuestUI    | UI/DialogUI.luau      | NPC dialogs, quests, shops, crafting      |
| BossUI     | UI/BossUI.luau        | Boss intro + health bar                   |
| DungeonUI  | UI/InstanceUI.luau    | Dungeon / raid lobbies, timers            |
