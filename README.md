# Knightfall - 2D Action Platformer

**Knightfall** is a fantasy-themed 2D action platformer game where you control a lone knight, navigating through dark dungeons filled with monsters and traps. The ultimate goal is to complete an ancient trial by defeating a final boss.

## 🎮 Beta Version Gameplay
[![Knightfall Beta Gameplay](https://img.youtube.com/vi/cn2WPqzRNf4/0.jpg)](https://youtu.be/cn2WPqzRNf4)

*Click the image above to watch the gameplay video*

## 📥 Download
**[Download Knightfall (Windows Releases)](https://github.com/sys-thai69/knightrun/releases)**

## Versioning
- Current release line: `v1.x`
- Recommended naming format: `v1.0.0`, `v1.1.0`, `v1.1.1`
- Example release title: `Knightfall v1.1.0 - Balance and Bugfix Update`

## 📋 Beta Testing Feedback
**[Fill out the Beta Testing Survey](https://docs.google.com/forms/d/e/1FAIpQLSdbfWZNHy8YupA_exoxSHMaR0FqJelLOzWNwIejQGqN-hv91w/viewform?usp=sharing&ouid=118429866648442793247)**

## Features
- **Player Movement**: Left, right, jump, and sword attack
- **Combat System**: Sword attacks, shield blocking, dash ability
- **Enemies**: Slimes, Skeleton Archers, Ghosts, Bomb Goblins, Shield Knights, and more
- **Boss Fight**: Summoner mini-boss that spawns minions and teleports
- **Coin System**: Collect coins to purchase upgrades at the shop
- **Shop System**: Buy sword, shield, dash, and upgrade stats
- **Checkpoint System**: Save progress at checkpoints throughout the level
- **Puzzle Elements**: Pressure plates, gates, and pushable blocks

## Controls
Move Left/Right | A / D or Arrow Keys |
Jump | Space or W |
Attack | J |
Block (Shield) | K |
Dash | Shift |
Interact | E |
Pause | Escape 

## Game Progression
- **Start**: Begin with a basic sword, low health, and weak enemies
- **Mid-Game**: Enemies become stronger, platforming gets more challenging, and upgrading becomes crucial
- **End-Game**: Dangerous enemies, limited healing, and a final boss battle

## Installation
To play the game, follow these steps:
1. Clone the repository:  
   `git clone https://github.com/sys-thai69/knightrun.git`
2. Open the project in Godot 4.x
3. Press **Play** to run the game
4. Or run exported files directly: `Knightrun.exe` with `Knightrun.pck` in the same folder

Or download the executable from the [Releases](https://github.com/sys-thai69/knightrun/releases) page.

## Submission Checklist (Rubric)
### 1. Game Release and Repository Quality
- [x] Repository is accessible and structured
- [ ] Latest playable build uploaded in GitHub Releases
- [x] README includes install and run instructions
- [ ] Clear release tags used (`v1.0.0`, `v1.1.0`, etc.)
- [ ] Game icon configured for project/export

### 2. Build Optimization and Size
- [x] Unused large assets removed
- [x] Runtime optimizations added (off-screen processing control, pre-generated effects)
- [ ] Final exported build size verified and documented

### 3. Bug Fixing and Beta Feedback
- [x] Instructor/feedback issues actively fixed in code
- [x] Beta feedback addressed (boss balance, projectile feel, puzzle interactions)
- [ ] Final release smoke-test passed with no critical bugs
- [x] Changelog/fixes list included

### 4. Game Completion Elements
- [x] Easter egg or bonus content documented
- [x] Clear ending/completion state exists (win screen/finish flow)

Bonus content currently included:
- Collectible lore scrolls with popup story text and completion tracking.
- Hidden/secret areas supported by breakable walls and exploration rewards.
- New Game+ mode unlocked from the win screen after completing the game.
- Hidden easter egg shrine in the main game map (interact to claim a secret reward and achievement).

Completion state currently included:
- Defeat the final boss, then reach the finish line to trigger the win flow.
- The win screen shows run stats, best time, scroll progress, and achievements.
- The player can restart, go to main menu, or start New Game+ from the ending screen.


## Credits
- **Game Developer**: Chhengthai Pheav
- **Assets**: Brackeys' Platformer Bundle (CC0 License)
- **Music**: Brackeys & Sofia Thirslund
- **Sound Effects**: Brackeys & Asbjørn Thirslund

## AI Disclosure
This project utilized claude for assistace
- Code assistance and debugging
- Feature implementation
- Bug fixes and optimization
- Game mechanics development

## License
This project is for educational purposes.
