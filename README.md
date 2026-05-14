# Go Chat — Flutter Real-Time Chat App

> Built on top of the [flutter-chat-starter](https://github.com/HNGi14/flutter-chat-starter) baseline.
> This project improves the rough starter — it does **not** rebuild it from scratch.

---

## What This Is

Go Chat is a production-grade, real-time messaging application built with Flutter and Firebase. Starting from a deliberately rough baseline that had 13 known gaps, this project closes every one of those gaps and then layers on six required advanced features — all while maintaining a clean MVVM architecture, a polished branded UI, and client-side media compression.

---

## Setup

Tested on **Flutter stable 3.41.x** (Dart 3.11.x). Run `flutter --version` to confirm your channel.

### 1. Clone & install dependencies

```sh
git clone https://github.com/Babajide-James/go-chat.git
cd go-chat/flutter-chat-starter
flutter pub get
```

### 2. Firebase configuration

1. Create a Firebase project at <https://console.firebase.google.com>.
2. Enable **Authentication → Sign-in method → Email/Password**.
3. Create **Cloud Firestore** in production mode.
4. Create a **Storage** bucket (default region is fine) — used for audio and media uploads routed through Supabase.
5. Install the FlutterFire CLI and regenerate the config against your project:

```sh
dart pub global activate flutterfire_cli
flutterfire configure   # regenerates lib/firebase_options.dart
```

### 3. Environment variables (`.env`)

The `.env` file is **intentionally excluded from Git** (it holds your Supabase credentials). You must obtain it from the project maintainer or create one yourself:

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

Place it at the root of `flutter-chat-starter/`. The `envied` package reads it at build time.

After placing the `.env` file, run the code generator:

```sh
dart run build_runner build --delete-conflicting-outputs
```

### 4. Firestore security rules

Paste the contents of `firestore.rules` into the **Firestore → Rules** tab and publish.

### 5. Run the app

```sh
flutter run
```

---

## Architecture

The project follows **MVVM (Model-View-ViewModel)** with `Provider` for state management.

```
lib/
├── core/
│   ├── constants/        # FirestorePaths
│   ├── enums/            # MessageType, MessageStatus
│   ├── services/         # AuthService, FirestoreService, StorageService
│   ├── theme/            # AppTheme (brand color palette)
│   ├── utils/            # MediaCompressor, Validators
│   └── widgets/          # LoadingIndicator, EmptyState, ErrorDisplay
├── env/                  # Envied-generated secrets accessor
├── models/               # Message, Conversation data models
├── viewmodels/           # AuthViewModel, ChatListViewModel, ChatViewModel
└── views/
    ├── auth/             # LoginView (unified login + sign-up)
    ├── chat/             # ChatView + widget folder
    │   └── widgets/      # MessageBubble, AudioBubble, MediaBubble,
    │                     # TypingIndicator, ReactionPicker, MessageActionsSheet,
    │                     # AudioRecorderBar, MediaPickerSheet,
    │                     # FullscreenImageView, FullscreenVideoView
    ├── chat_list/        # ChatListView (conversation list)
    └── new_chat/         # NewChatSearchView (user search to start a conversation)
```

---

## Firestore Schema

```
users/{uid}
  └── uid, email, displayName, createdAt

conversations/{convId}
  ├── participants: [uid, uid]
  ├── lastMessage: string
  ├── lastMessageAt: timestamp
  └── typing: { uid: timestamp | deleted }

conversations/{convId}/messages/{msgId}
  ├── senderId
  ├── text (nullable)
  ├── type: "text" | "audio" | "image" | "video"
  ├── mediaUrl (nullable)
  ├── thumbnailUrl (nullable)
  ├── audioDuration (nullable)
  ├── createdAt
  ├── status: "sent" | "delivered" | "seen"
  ├── readBy: { uid: timestamp }
  ├── reactions: { uid: emoji }
  ├── editedAt (nullable)
  ├── deletedFor: [uid] (soft delete for sender only)
  └── deletedForEveryone: bool
```

---

## Features Implemented

### Prerequisite: New Chat Flow
Users can search other registered accounts by **display name** or **email address**. A new `conversations` document is created automatically if one does not already exist between the two participants. Conversations persist across sessions — all chat history is stored in Firestore.

### Feature 1 — Real-Time Typing Indicator
- The `ChatViewModel` writes to `conversations/{id}/typing/{uid}` using Firestore's server timestamp.
- A debounce timer (1 s keystroke gap) prevents excessive writes.
- An idle timer (2 s of no input) clears the typing flag automatically.
- The `TypingIndicator` widget displays animated bouncing dots in the brand orange palette.

### Feature 2 — Emoji Reactions
- Long-press any message bubble to reveal a floating `ReactionPicker` (6 emojis: 👍 ❤️ 😂 😮 😢 🙏).
- `ChatViewModel.toggleReaction()` handles both add and remove (same emoji = toggle off).
- Reactions are stored per-user in `messages/{id}/reactions/{uid}` using Firestore dot-notation field paths.
- Reaction counts are grouped and displayed as chips below the bubble.

### Feature 3 — Audio Messages (Voice Notes)
- Tap the mic icon to swap the text input for `AudioRecorderBar`.
- Recording uses the `record` package; an elapsed timer is displayed live.
- Sending stops the recording, compresses the file, uploads it to Supabase Storage, and writes a message doc with `type: audio`.
- `AudioBubble` renders the message with a play/pause button, waveform progress bar, elapsed counter, and a **1× / 2× speed toggle**.

### Feature 4 — Image & Video Messages
- Tap the 📎 attachment icon to open `MediaPickerSheet` (Gallery, Camera, Video).
- **Client-side compression is mandatory and enforced before upload:**
  - Images: resized to max 1080 × 1080 px, JPEG quality 80%.
  - Videos: re-encoded to 720p H.264.
- A branded snackbar appears immediately after compression showing before and after file sizes and the savings percentage, e.g.:
  ```
  📷  2.34 MB → 0.87 MB  (63% smaller)
  ```
- `MediaBubble` renders a rounded thumbnail with an upload progress overlay and a play icon for videos.
- Tap a thumbnail to open `FullscreenImageView` (pinch-zoom) or `FullscreenVideoView` (Chewie player).

### Feature 5 — Read Receipts
- `MessageStatus` enum tracks `sending → sent → delivered → seen`.
- Every message becomes visible in the viewport triggers `markAsRead()` via `VisibilityDetector` (50 % visibility threshold).
- `firestore_service.dart → markMessageAsRead()` writes `readBy.{uid}: serverTimestamp` and sets `status: seen`.
- Outgoing messages display ticks: single grey = sent, double grey = delivered, double blue = seen.

### Feature 6 — In-Chat Search
- Tap the 🔍 icon in the chat AppBar to toggle a search text field.
- Messages are filtered client-side in real time using `searchQuery`.
- Matching substrings in message text are highlighted with a yellow background using `RichText`.

### Feature 7 — Edit & Delete Messages
- Long-press any message to open `MessageActionsSheet` (bottom sheet).
- **Edit:** Pre-fills the input field and shows an "Editing" banner with a cancel option. Ownership is verified before the Firestore write.
- **Delete for me:** Soft-deletes by appending the user's UID to `deletedFor[]`. The message is hidden only for the requester.
- **Delete for everyone:** Sets `deletedForEveryone: true` and nulls `text` and `mediaUrl`. A tombstone placeholder is displayed to all participants.
- Edited messages show an "edited" label below the bubble.

---

## Brand & UI

| Token | Value | Usage |
|---|---|---|
| International Orange | `#FF4F00` | Buttons, send icon, active states |
| Burnt Sienna | `#E97451` | Secondary borders, accents |
| Seashell | `#FFF5EE` | Scaffold background, input fill |
| Rust | `#A0522D` | Primary text, icon labels |

The auth screen is a single scrollable view (wrapped in `SingleChildScrollView`) that handles keyboard overlap gracefully. The chat list resolves each partner's `displayName` asynchronously and displays initials as an avatar while loading.

---

## What Was Fixed from the Starter's 13 Known Gaps

| # | Original Gap | Resolution |
|---|---|---|
| 1 | No loading indicator during `ConnectionState.waiting` | `LoadingIndicator` widget used throughout |
| 2 | No error UI on `snapshot.hasError` | `ErrorDisplay` widget and try/catch wrappers |
| 3 | No empty states | `EmptyState` widget with contextual messages |
| 4 | No scroll-to-latest on new message | `ScrollController` in `ChatViewModel` |
| 5 | No auth route guard | `StreamBuilder<User?>` in `App` redirects unauthenticated users |
| 6 | All state in `setState` | Full MVVM: `AuthViewModel`, `ChatListViewModel`, `ChatViewModel` with `Provider` |
| 7 | Streams set up in `build()` | Streams owned by ViewModels, not widgets |
| 8 | No input validation | `Validators` utility + `Form` + `TextFormField` validators |
| 9 | No `try/catch` around Firebase calls | All async calls wrapped; `FirebaseAuthException` messages surfaced to UI |
| 10 | No offline persistence config | Firestore SDK mobile defaults; messages remain readable while offline |
| 11 | No user profile creation | `AuthViewModel.signUp()` writes `users/{uid}` doc on registration |
| 12 | No way to start a new conversation | `NewChatSearchView` with dual search (displayName + email) |
| 13 | No `dispose()` cleanup | `StreamSubscription`, `Timer`, `TextEditingController`, and `ScrollController` all disposed |

---

## Key Dependencies

| Package | Purpose |
|---|---|
| `firebase_auth` | User authentication |
| `cloud_firestore` | Real-time database |
| `firebase_storage` | Not used (avoided to prevent billing) |
| `supabase_flutter` | Media and audio file storage |
| `provider` | MVVM state management |
| `record` | Audio recording |
| `audioplayers` | Audio playback |
| `flutter_image_compress` | Client-side image compression |
| `video_compress` | Client-side video compression |
| `image_picker` | Gallery and camera picker |
| `cached_network_image` | Efficient remote image rendering |
| `photo_view` | Fullscreen pinch-zoom image viewer |
| `chewie` / `video_player` | Fullscreen video playback |
| `visibility_detector` | Viewport-based read receipt triggering |
| `connectivity_plus` | Network state monitoring |
| `envied` | Compile-time secret injection from `.env` |

---

## Notes

- `lib/firebase_options.dart` is a placeholder stub committed so the project compiles out of the box. Replace it locally by running `flutterfire configure`.
- `.env` is gitignored. The app will throw at Supabase initialization if this file is absent.
- The project targets **Android API 21+** (Lollipop). iOS support is present but untested.
- `dart analyze lib` currently reports **0 errors, 0 warnings**.
