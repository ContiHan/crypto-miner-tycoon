# Bitcoin Idle Tycoon

A cross-platform idle strategy game built with Flutter.

## 🎮 Game Concept
Manage a crypto mining farm, upgrade from weak CPUs to Quantum Computers, and execute "Hard Forks" (Prestige) to reset for permanent multipliers.

## 🛠 Features Implemented
- **Core Loop**: Automatic income generation (Hash Rate) and Manual Mining (Clicker).
- **Economy**:
  - Exponential cost scaling for Rigs.
  - 4 Tiers of Rigs: CPU, GPU, ASIC, Quantum.
- **Prestige System**:
  - **GovTokens**: Earned by resetting progress (Hard Fork).
  - Multiplier: +10% income per token.
- **Visuals**:
  - "Cyber-Industrial" theme (Dark Slate + Amber).
  - Custom `StylizedCard` widgets with cut corners and borders.

## 📂 Project Structure
- `lib/main.dart`: Entry point & Theme setup.
- `lib/providers/game_logic.dart`: The "Brain" of the game. Handles timer, mining, and buying logic.
- `lib/models/rig.dart`: Data model for mining equipment.
- `lib/screens/home_screen.dart`: Main UI.
- `lib/widgets/`: Reusable UI components.

## 🚀 Roadmap / Todo
- [ ] **Persistence**: Save game state to local storage (so progress isn't lost on close).
- [ ] **Offline Earnings**: Calculate money earned while the app was closed.
- [ ] **Animations**: Spinning fans, floating text for earnings.
- [ ] **Sound**: Click sounds, ambient server hum.
- [ ] **Research Tree**: Unlock passive upgrades (e.g., "Cheaper Energy").

## 👨‍💻 How to Run
1. Open terminal in this folder.
2. Run `flutter run` (select Emulator or Windows).
