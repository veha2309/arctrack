# ArcTrack

ArcTrack is an Android-first Flutter gym tracker for planning training splits,
logging workouts quickly, and reviewing progress. It is designed as a focused
training tool: compact layouts, restrained visuals, fast set entry, and no
account or mandatory cloud service.

All training data is stored locally in SQLite. Optional JSON backup can write to
a user-selected local file or a file exposed by Android's Google Drive document
provider.

## Features

- Four main areas: Home, Train, Program, and Insights. Workout history and
  backup remain available from Insights and settings.
- Rolling training rotations with repeatable rest days.
- Fixed seven-day weekly schedules, including rest and unscheduled days.
- Custom exercises and reusable workout routines.
- Strength, bodyweight, timed, and distance exercise types.
- Fast workout logging with previous values, set completion, optional advanced
  fields, and exercise-specific rest timers.
- Add, insert, or remove exercises while a workout is active.
- Resume an interrupted workout after restarting the app.
- Delete routines or individual completed workouts with confirmation.
- Body weight, measurements, recovery check-ins, workload, estimated 1RM,
  records, frequency, and streak tracking.
- Kilograms/pounds and metric/imperial display conversion while retaining
  normalized metric values internally.
- Excel-based bulk plan and history import.
- CSV history export and JSON backup/restore.
- Optional single-file automatic backup through Android's document provider.
- Native Android splash screen, adaptive launcher icon, and double-back exit.

## Main areas

### Home

Shows the next workout, a direct start or resume action, recent training
momentum, the upcoming schedule, and an optional self-reported recovery
check-in. A missed day does not silently advance a rolling rotation.

### Program

Create or edit routines, manage exercises, choose between a rolling rotation
and fixed weekly schedule, add rest days, reorder rotation entries, or import a
complete plan from Excel. Deleting a routine removes its schedule references
but keeps historical workouts.

### Train

Log weight and repetitions, complete sets, add or remove sets, access optional
set details, and run the configured rest timer. Exercises can be appended or
inserted after a particular movement during the session. Changes are autosaved.

### Insights

Compares four-week workout frequency, shows weekly workouts or working sets on
their own scale, and charts exercise trends with dated sessions and range
filters. It also includes body-weight trends and personal records.

### History

Open from Insights or Home settings to review or delete completed workouts,
export CSV/JSON, restore a JSON backup, and configure automatic backup.

## Backup and restore

ArcTrack provides three JSON workflows:

1. **Share JSON backup** sends a snapshot through Android's share sheet.
2. **Restore file** or **Paste JSON** validates a backup, shows a summary, and
   asks for confirmation before replacing local data.
3. **Choose backup file** creates one persistent backup file. After each data
   update, ArcTrack overwrites that same file instead of creating dated copies.

When Google Drive is selected in Android's file picker, Drive is responsible for
uploading and retrying synchronization when internet access is available.
ArcTrack itself remains usable offline and does not request Google credentials.

Uninstalling the app removes its saved permission to the backup location, but
does not delete the backup file. After reinstalling:

1. Open History and select **Restore file**.
2. Choose the existing `ArcTrack_backup.json` file and restore it.
3. Select **Use existing** and choose the same file to resume automatic updates
   without creating another backup.

Automatic backup is optional and can be disabled from History. Local SQLite
saving remains the source of truth if the selected document provider is
temporarily unavailable.

## Excel bulk import

From Plan, choose **Share Excel template**, edit the workbook, then select
**Import Excel**.

The workbook uses these sheets:

### `Plan`

| Column | Purpose |
| --- | --- |
| `mode` | `rolling` or `weekly` |
| `slot` | Rotation number (`1`, `2`, ...) or weekday name |
| `workout` | Routine name; use `Rest` for a rest day |
| `exercise` | Exercise name; leave empty for Rest |
| `muscle` | Primary muscle group |
| `type` | `strength`, `bodyweight`, `timed`, or `distance` |
| `sets` | Target set count, from 1 to 20 |
| `reps` | Target repetitions |
| `rest_seconds` | Rest duration, from 0 to 900 seconds |

Use one row per exercise. Repeat the same mode, slot, and workout values for all
exercises belonging to one routine.

### `History`

| Column | Purpose |
| --- | --- |
| `date` | `YYYY-MM-DD HH:MM` |
| `workout` | Workout name |
| `exercise` | Exercise name |
| `set` | Set number |
| `weight_kg` | Weight in kilograms |
| `reps` | Completed repetitions |
| `completed` | `true` or `false` |

Matching routine names are updated. Existing workout history is retained, and
reimporting the same dated workout does not create another copy.

## Development setup

### Requirements

- Flutter SDK compatible with Dart `>=3.4.0 <4.0.0`
- Android SDK with API 36 available
- Java 17
- An Android device or emulator

Check the environment and install packages:

```powershell
flutter doctor
flutter pub get
```

Run the app:

```powershell
flutter run
```

Run static analysis and tests:

```powershell
flutter analyze
flutter test
```

Build an installable debug APK:

```powershell
flutter build apk --debug
```

The APK is written to:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Architecture

```text
lib/
├── application/   Riverpod controller and application operations
├── data/          SQLite repository, Excel import, and backup bridge
├── domain/        Serializable domain models and calculations
├── ui/            Theme, shared widgets, and feature screens
└── main.dart      Routing, app shell, and Android back handling
```

- **Riverpod** manages application state and autosave coordination.
- **GoRouter** provides the five-section navigation shell.
- **Drift/SQLite** stores a serialized, version-tolerant local data model.
- Stable IDs keep domain records independent from presentation and allow a
  future repository implementation to add synchronization.
- The Android document-provider bridge retains access to exactly one selected
  backup URI and rewrites its contents after meaningful changes.

## Data and privacy

- No account is required.
- No analytics, advertising, or social features are included.
- The primary database stays inside the app's private storage.
- ArcTrack accesses a backup file only after the user selects it through the
  Android system picker.
- Importing a JSON backup replaces the current local dataset after confirmation.

## Current limitations

- Android is the actively supported target; the native automatic-backup bridge
  is not yet implemented for iOS.
- Reminder scheduling and progress-photo capture are not yet exposed in the UI.
- Google Drive availability depends on the Drive app/document provider installed
  and configured on the device.
- Release signing is not configured. The current release build configuration
  uses the debug signing key and must be replaced before store distribution.
- There is currently one local profile and no social, wearable, or trainer
  integration.

## Project status

ArcTrack is an actively developed local application. Before distributing a
production build, configure a private release keystore, update the application
version, review Android permissions, and test backup behavior with the intended
document provider and Android versions.
