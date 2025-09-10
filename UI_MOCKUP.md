# URL Sharing Feature - UI Flow

This document describes the user interface flow for the URL sharing feature.

## 1. Main URL List View (ContentView)

```
┌─────────────────────────────────────────┐
│ ← [👤]           Saved URLs       [🔄] │
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 📄 Swift Programming Guide         │ │
│ │ https://docs.swift.org/guide        │ │
│ │                                     │ │
│ │ Comprehensive guide covering...     │ │
│ │                                     │ │
│ │ [swift] [programming] [docs]        │ │
│ │                                     │ │
│ │ Ready ✅    Synced ☁️              │ │
│ │ Created 2 hours ago                 │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 🔄 Processing Article...            │ │
│ │ https://techcrunch.com/article      │ │
│ │                                     │ │
│ │ Processing ⏳  Syncing 🔄           │ │
│ │ Created 5 minutes ago               │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 📰 https://news.ycombinator.com     │ │
│ │                                     │ │
│ │ Local Only 📱  Sync Failed ⚠️       │ │
│ │ Created 1 day ago                   │ │
│ └─────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### Features Shown:
- Clean list layout with URL cards
- Status badges with colors and icons
- Preview of content (title, summary, tags)
- Timestamps and sync status
- Pull-to-refresh capability
- User account access (👤 icon)
- Manual sync button (🔄 icon)

## 2. Empty State (No URLs)

```
┌─────────────────────────────────────────┐
│ ← [👤]           Saved URLs       [🔄] │
├─────────────────────────────────────────┤
│                                         │
│               🔗                        │
│                                         │
│         No URLs saved yet               │
│                                         │
│   Share URLs to Hamrah from Safari,    │
│   Mail, or other apps to get started.  │
│                                         │
│                                         │
│                                         │
│                                         │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

## 3. URL Detail View

```
┌─────────────────────────────────────────┐
│ ← URL Details                           │
├─────────────────────────────────────────┤
│                                         │
│ Swift Programming Guide                 │
│                                         │
│ 🔗 https://docs.swift.org/guide        │
│                                         │
│ Ready ✅    Synced ☁️                  │
│                                         │
│ Summary                                 │
│ A comprehensive guide to Swift          │
│ programming language covering syntax,   │
│ concepts, and best practices for iOS    │
│ and macOS development.                  │
│                                         │
│ Tags                                    │
│ ┌─────┐ ┌─────────────┐ ┌──────┐      │
│ │swift│ │programming  │ │docs  │      │
│ └─────┘ └─────────────┘ └──────┘      │
│ ┌─────────┐ ┌─────┐                   │
│ │tutorial │ │guide│                   │
│ └─────────┘ └─────┘                   │
│                                         │
│ Details                                 │
│ Created: Dec 10, 2024 at 2:15 PM      │
│ Updated: Dec 10, 2024 at 2:18 PM      │
│                                         │
└─────────────────────────────────────────┘
```

## 4. Sharing Flow (From Safari)

### Step 1: Safari Share Sheet
```
┌─────────────────────────────────────────┐
│           🌐 Safari                     │
│                                         │
│    Viewing: https://example.com         │
│                                         │
│         [Share Button Tapped]           │
│                                         │
│    ┌─────────────────────────────────┐  │
│    │        Share Options            │  │
│    │                                 │  │
│    │  [📱] Messages  [📧] Mail       │  │
│    │  [🔗] Copy Link  [📄] Notes     │  │
│    │  [⭐] Hamrah    [📑] Reading    │  │
│    │                                 │  │
│    └─────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Step 2: Hamrah App Opens
```
┌─────────────────────────────────────────┐
│           ⭐ Hamrah                     │
├─────────────────────────────────────────┤
│                                         │
│              ✅ Saved!                  │
│                                         │
│    URL has been saved to your library  │
│                                         │
│       https://example.com               │
│                                         │
│    [View in Library] [Done]             │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

## 5. Status Indicators

### Processing Status
- **Pending** ⏳ (Orange): URL saved, waiting for processing
- **Processing** 🔄 (Blue): Backend extracting content
- **Ready** ✅ (Green): Processing complete, content available
- **Failed** ❌ (Red): Processing failed

### Sync Status  
- **Local Only** 📱 (Gray): Only stored locally
- **Syncing** 🔄 (Blue): Uploading to backend
- **Synced** ☁️ (Green): Successfully synchronized
- **Sync Failed** ⚠️ (Red): Network error, will retry

## 6. Context Menu Actions

```
┌─────────────────────────────────────────┐
│ [Long press on URL item]                │
│                                         │
│    ┌─────────────────────────────────┐  │
│    │  🔗 Open in Safari              │  │
│    │  📋 Copy URL                    │  │
│    │  📤 Share                       │  │
│    │  🔄 Retry Sync                  │  │
│    │  🗑️ Delete                      │  │
│    └─────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

## 7. Pull-to-Refresh Animation

```
┌─────────────────────────────────────────┐
│ ← [👤]           Saved URLs       [🔄] │
├─────────────────────────────────────────┤
│                🔄                       │
│         Syncing URLs...                 │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 📄 Swift Programming Guide         │ │
│ │ Ready ✅    Syncing 🔄              │ │
│ └─────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

## Design Principles

### 1. **Clarity**
- Clear status indicators with recognizable icons
- Obvious visual hierarchy
- Readable typography and adequate spacing

### 2. **Immediate Feedback**
- URLs save instantly when shared
- Visual confirmation of actions
- Real-time status updates

### 3. **Offline-First**
- All actions work offline
- Clear indication of sync status
- No blocking operations

### 4. **Progressive Disclosure**
- Summary view shows essential information
- Detailed view reveals full content
- Contextual actions when needed

### 5. **Accessibility**
- VoiceOver support for all elements
- Sufficient color contrast
- Meaningful accessibility labels
- Dynamic type support