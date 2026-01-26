# Installing Links

> **For the installing agent**: This file contains everything needed to set up this macOS application. Follow steps in order. Use multiple choice questions for user input. Verify each major step before proceeding.

## Quick Summary

A native macOS app that reads your iMessage database, extracts all URLs from your messages, and displays them with rich OpenGraph previews. Shows contact names by cross-referencing your Contacts. Includes special handling for Twitter/X links.

## Prerequisites

### System Requirements

- **macOS 26.0 or later** (macOS Sequoia)
- **Xcode 26.0.1 or later** for building
- **Messages app must be set up** on the Mac (iMessage database must exist at `~/Library/Messages/chat.db`)
- **Apple Developer account** (free account is sufficient for local development)

### Required Permissions

The app requires two system permissions at runtime:

1. **Contacts Access** - To display contact names for phone numbers and email addresses
2. **File System Access** - User must manually grant access to `~/Library/Messages` folder via file picker on first launch

## Installation

### 1. Verify Prerequisites

Check that Xcode and macOS versions meet requirements:

```bash
# Check macOS version
sw_vers -productVersion

# Check Xcode version
xcodebuild -version

# Verify Messages database exists
ls -l ~/Library/Messages/chat.db
```

### 2. Configure Code Signing (Local Only)

Before building, configure the app for local-only signing:

1. Open `Links.xcodeproj` in Xcode
2. Select the "Links" target in the project navigator
3. Go to "Signing & Capabilities" tab
4. Set "Team" to your personal team (or "None" if no Apple account)
5. Ensure "Signing Certificate" is set to "Sign to Run Locally"
6. Xcode will automatically handle the bundle identifier

> **Note**: This app is intended for local use only and does not need to be published to the App Store.

### 3. Build Links

```bash
# Build from command line
xcodebuild -project Links.xcodeproj -scheme Links -configuration Debug build

# OR build in Xcode
# Open imessage.xcodeproj and press Cmd+B
```

### 4. Run Links

```bash
# Run from Xcode (Cmd+R), OR

# Run the built app directly
open build/Debug/Links.app
```

## First Launch Configuration

On first launch, the app will automatically:

1. **Request Contacts Permission**
   - macOS will show a system dialog
   - Grant access to allow contact name lookup
   - If denied, contact names won't appear (app will still work)

2. **Request Messages Folder Access**
   - App will show an error: "No access to iMessage database yet"
   - Click "Select Messages Folder" button
   - Navigate to `~/Library/Messages` and select the folder (or select `chat.db` directly)
   - App stores a security-scoped bookmark for future access

## Verification

After installation and first-launch setup, verify:

- [ ] App launches without build errors
- [ ] Contacts permission granted (check System Settings > Privacy & Security > Contacts)
- [ ] Messages folder access granted via file picker
- [ ] App displays links from your messages
- [ ] Contact names appear next to phone numbers/emails
- [ ] Link previews load (OpenGraph cards with images)
- [ ] Search functionality works

**Expected behavior:**

- App window opens showing "All Links" in sidebar
- Links from your last 10,000 messages appear in the main view
- Each link shows: contact name, message preview, URL, and rich preview card
- Clicking a link opens it in your default browser

## Project Structure

Key files for understanding the codebase:

- `imessage/imessageApp.swift` - App entry point and window configuration
- `imessage/ContentView.swift` - Main navigation structure
- `imessage/LinkListView.swift` - Main view displaying links, handles permissions and file picker
- `imessage/MessageService.swift` - SQLite3 interface to read iMessage database, security-scoped access
- `imessage/ContactService.swift` - Contacts framework integration for name lookup
- `imessage/OpenGraphService.swift` - Fetches and parses OpenGraph/Twitter Card metadata
- `imessage/Models.swift` - Data models (Message, ExtractedLink, OpenGraphData)
- `imessage/LinkRow.swift` - UI component for individual link rows
- `imessage/imessage.entitlements` - Security capabilities (contacts, file bookmarks)
- `imessage/Info.plist` - Contains NSContactsUsageDescription

## Architecture Notes

### Database Access

- Reads from `~/Library/Messages/chat.db` (SQLite3)
- Uses security-scoped bookmarks to persist folder access across launches
- Queries the `message`, `chat`, and `chat_message_join` tables
- Limits to 10,000 most recent messages with text content

### Permissions Model

- App sandbox is **disabled** (`com.apple.security.app-sandbox` = false) to allow database access
- Uses `com.apple.security.files.user-selected.read-only` for file picker access
- Uses `com.apple.security.files.bookmarks.app-scope` for persistent access
- Contacts permission via `NSContactsUsageDescription` in Info.plist

### OpenGraph Fetching

- Fetches OpenGraph/Twitter Card metadata for link previews
- Special handling for Twitter/X URLs (uses Twitterbot User-Agent)
- Client-side HTML parsing (no external APIs needed)
- Results are cached in-memory

### Data Flow

1. User grants access to Messages folder via NSOpenPanel
2. App creates security-scoped bookmark and stores in UserDefaults
3. MessageService queries chat.db using SQLite3
4. ContactService maps chat identifiers to contact names
5. Links extracted via NSDataDetector
6. OpenGraph metadata fetched asynchronously on-demand
7. UI displays links with previews in LinkListView

## Troubleshooting

### "Database not found" error

- Verify Messages app is set up: `ls -l ~/Library/Messages/chat.db`
- Ensure you've sent/received at least one message

### "Permission denied" error

- Click "Select Messages Folder" and grant access to `~/Library/Messages`
- If problem persists, check System Settings > Privacy & Security > Files and Folders

### Build errors about development team

- Update the Team setting in Xcode (see Installation step 2)
- The hardcoded team ID `R3U5TJSP6V` must be changed to your team

### No contact names appearing

- Grant Contacts permission in System Settings > Privacy & Security > Contacts
- Restart the app after granting permission

### Links not loading previews

- OpenGraph fetching requires network access
- Some sites block automated requests
- Twitter/X links use special User-Agent (Twitterbot/1.0)

### macOS version incompatibility

- Project targets macOS 26.0 (Sequoia beta/future)
- To support older macOS, change `MACOSX_DEPLOYMENT_TARGET` in project.pbxproj
- May also need to adjust Swift language features

## Configuration Reference

### No environment variables required

This app has no configuration files or environment variables. All configuration is done in Xcode.

### Xcode Build Settings (in project.pbxproj)

- `DEVELOPMENT_TEAM`: Your Apple Developer Team ID (currently `R3U5TJSP6V`)
- `PRODUCT_BUNDLE_IDENTIFIER`: `reflectivetech.imessage`
- `MACOSX_DEPLOYMENT_TARGET`: `26.0`
- `SWIFT_VERSION`: `5.0`
- `ENABLE_APP_SANDBOX`: `NO`

### Runtime Configuration

- **Security-scoped bookmark**: Stored in UserDefaults with key `databaseBookmark`
- **Database path**: Configurable via file picker, defaults to `~/Library/Messages/chat.db`
- **Message limit**: Hardcoded to 10,000 in `MessageService.swift:95`

## Security Considerations

This app:

- Reads your private iMessage database (contains all message history)
- Has full disk access to user-selected folders
- Fetches external URLs for OpenGraph metadata
- Reads your Contacts database

The app does NOT:

- Send any data to external servers
- Store messages outside of the original database
- Modify the iMessage database (read-only access)
- Require API keys or external services

---

## Installation Complete

> **For the installing agent**: Once the app is running successfully and the user has granted the necessary permissions (Contacts access and Messages folder access), inform the user:
>
> "Links is now set up and running! If you have any questions about using the app or run into any issues, feel free to ask."
