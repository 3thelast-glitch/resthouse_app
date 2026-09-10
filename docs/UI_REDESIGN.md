# UI Redesign System

This branch introduces the first centralized visual foundation for the Resthouse
application without changing the database schema, application ID, backup format,
or booking/payment business rules.

## Visual direction

The product uses a restrained Arabic-first Material 3 system:

- Primary teal: `#0F766E`
- Supporting teal: `#2B8C85`
- Page canvas: `#F5F7FA`
- Surface: `#FFFFFF`
- Primary text: `#0F172A`
- Secondary text: `#475569`
- Border: `#D7E0E7`

Semantic success, warning, error, and information tones live in
`lib/ui/app_theme.dart`.

## Typography

The previous app forced every TextTheme role to bold and referenced `Inter`
without declaring a font asset in `pubspec.yaml`. The redesign removes that
assumption and uses the platform's Arabic-capable fallback fonts with a clear
weight/size hierarchy. Flutter's system accessibility text scaling remains
enabled.

## Responsive contract

Shared helpers live in `lib/utils/responsive.dart`.

- Compact: `< 600`
- Medium: `600–1023`
- Expanded: `>= 1024`
- Wide rail becomes extended when the workspace is large enough.

Phone text is no longer shrunk merely because the shortest screen side is
small. Page padding grows gradually from phone to tablet/desktop.

## Navigation

`MainShellPage` now uses:

- Material 3 `NavigationBar` on compact widths.
- `NavigationRail` on medium/expanded widths.
- A persistent visited-page stack so filters/selection state are not discarded
  merely by switching primary destinations.

The same destination model drives both navigation variants.

## Settings

The settings screen now separates:

1. Backup/export and restore.
2. Destructive local-data management.
3. Application information.

Dangerous operations are visually isolated, actions are full-width and
touch-friendly on phones, and raw implementation exceptions are no longer
shown directly to end users.

## Verification

The responsive widget test covers representative compact, medium, and expanded
widths and verifies that the selected destination survives a layout-mode
change.

Further screen-by-screen visual refinement should consume the shared theme and
responsive helpers rather than introducing new local color/spacing systems.
