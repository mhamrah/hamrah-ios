# URL Sharing Feature

This document describes the URL sharing feature implementation in the hamrah-ios app.

## Overview

The URL sharing feature allows users to save URLs shared from other apps (Safari, Mail, etc.) to the Hamrah app for processing and organization. The feature follows an offline-first approach, ensuring URLs can be saved even when the device is offline.

## Features

### 1. URL Sharing Support
- Accepts URLs shared from other iOS apps via the system share sheet
- Supports both HTTP and HTTPS URLs
- Automatic URL validation before saving

### 2. Offline-First Storage
- URLs are immediately saved to local SwiftData storage
- No network connection required for saving
- Automatic sync with backend when online

### 3. Processing Status Tracking
- **Pending**: URL saved locally, waiting for backend processing
- **Processing**: Backend is currently extracting content
- **Completed**: Processing finished, title/summary/tags available
- **Failed**: Processing encountered an error

### 4. Sync Status Management
- **Local Only**: URL only stored locally
- **Syncing**: Currently uploading to backend
- **Synced**: Successfully synchronized with backend
- **Sync Failed**: Network error, will retry later

### 5. Rich Content Display
- Extracted title and summary from URLs
- Auto-generated tags for content categorization
- Creation and update timestamps
- Status indicators with appropriate colors and icons

## Architecture

### Data Models

#### SavedURL (SwiftData Model)
```swift
@Model
final class SavedURL {
    var id: UUID                        // Local identifier
    var url: String                     // Original URL
    var title: String?                  // Extracted title
    var summary: String?                // Content summary
    var tags: [String]                  // Auto-generated tags
    var processingStatus: ProcessingStatus
    var syncStatus: SyncStatus
    var createdAt: Date
    var updatedAt: Date
    var backendId: String?              // Backend identifier
}
```

### Services

#### URLManager
- Main coordinator for URL operations
- Handles saving, syncing, and deleting URLs
- Manages offline/online state transitions
- Implements retry logic for failed syncs

#### SecureAPIService Integration
- Uses existing secure API service for backend communication
- Includes App Attestation headers for security
- Proper error handling and authentication

### User Interface

#### ContentView (Updated)
- Replaced placeholder Item list with SavedURL management
- Pull-to-refresh and manual sync buttons
- Status badges showing processing and sync states
- Context menus for URL actions

#### SavedURLRow
- Compact URL display with title, summary preview
- Status indicators with color coding
- Tag display in horizontal scroll view
- Timestamp information

#### SavedURLDetailView
- Full URL details with clickable link
- Complete summary and tag display
- Processing and sync status information
- Creation and update timestamps

## URL Handling Flow

1. **URL Reception**: User shares URL to Hamrah app
2. **Local Storage**: URL immediately saved to SwiftData
3. **Background Sync**: Automatic upload to backend when online
4. **Processing**: Backend extracts title, summary, and tags
5. **Status Updates**: App polls for processing completion
6. **UI Updates**: Real-time status and content updates

## Network Behavior

### Offline Mode
- URLs saved locally with "Local Only" status
- No network operations attempted
- User can continue saving URLs without limitation

### Online Mode
- Automatic sync of pending URLs
- Background polling for processing updates
- Retry logic for failed network requests
- User-initiated refresh capabilities

### Hybrid Mode
- Seamless transition between offline/online
- Queued operations execute when connectivity restored
- No data loss during network transitions

## Configuration

### URL Schemes (Info.plist)
```xml
<dict>
    <key>CFBundleURLName</key>
    <string>SharedURLs</string>
    <key>CFBundleTypeRole</key>
    <string>Viewer</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>http</string>
        <string>https</string>
    </array>
</dict>
```

### SwiftData Schema
```swift
let schema = Schema([
    Item.self,      // Existing model (can be removed)
    SavedURL.self,  // New URL model
])
```

## Testing

### Unit Tests
- URL validation and saving
- Duplicate prevention
- Backend response parsing
- Status enum functionality
- Model updates and synchronization

### Integration Tests
- End-to-end URL sharing flow
- Network error handling
- Offline/online transitions
- SwiftData persistence

## API Requirements

See `API_ENDPOINTS.md` for complete backend API specifications.

### Key Endpoints
- `POST /api/urls` - Submit new URL
- `GET /api/urls/{id}` - Get URL details
- `GET /api/urls` - List user's URLs
- `DELETE /api/urls/{id}` - Delete URL

## Error Handling

### Network Errors
- Automatic retry with exponential backoff
- Graceful degradation to offline mode
- Clear error messages to user

### Validation Errors
- Invalid URL format rejection
- Duplicate URL prevention
- Backend error propagation

### Storage Errors
- SwiftData error handling
- Keychain integration for sensitive data
- Data consistency verification

## Security Considerations

### App Attestation
- All API requests include attestation headers
- Prevents tampering and unauthorized access
- Validates app authenticity

### Data Protection
- URLs stored securely in SwiftData
- Authentication tokens in Keychain
- No sensitive data in UserDefaults

### Privacy
- URLs only accessible to authenticated user
- No cross-user data leakage
- Secure deletion of user data

## Performance

### Local Storage
- Fast SwiftData queries with predicates
- Efficient UI updates with @Query
- Minimal memory footprint

### Network Optimization
- Batched API requests where possible
- Background processing status updates
- Efficient JSON parsing

### UI Responsiveness
- Immediate local saves
- Async network operations
- Smooth animations and transitions

## Future Enhancements

### Planned Features
- URL categories and folders
- Full-text search across saved content
- Export functionality
- Sharing URLs with other users
- Bulk operations (delete, tag, etc.)

### Technical Improvements
- Background app refresh integration
- Push notifications for processing completion
- Advanced caching strategies
- Improved error recovery