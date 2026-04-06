# orthodoxy_widget_365

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## FVM Setup (Pinned Flutter)

This project is pinned to Flutter `3.24.5` via `.fvmrc`.

### One-time machine setup

```bash
dart pub global activate fvm
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Project setup

```bash
cd /Users/nikoskaradimas/Desktop/glass_Widget_365
fvm use 3.24.5 --force
fvm flutter pub get
```

### Run commands (recommended)

```bash
fvm flutter test
fvm flutter run -d chrome
```

### Optional (VS Code terminal convenience)

After opening the project in VS Code, restart the terminal so `flutter` resolves
to the FVM-managed SDK automatically for this workspace.
