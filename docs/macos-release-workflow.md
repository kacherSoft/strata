# macOS Release Workflow (TaskManager)

## 1) One-time setup
1. Open `TaskManager/TaskManagerApp.xcodeproj`.
2. In **Xcode → Settings → Accounts**, sign in with Apple ID that has App Store Connect access.
3. In target **TaskManager → Signing & Capabilities** (Debug + Release):
   - Enable **Automatically manage signing**.
   - Select your **Team**.
   - Set unique **Bundle Identifier**.
4. In App Store Connect, create app record once:
   - **My Apps → + → New App**.
   - Platform: macOS, same Bundle ID.

## 2) Day-to-day development updates
1. Pull latest code.
2. Regenerate project (safe to run anytime):
   ```bash
   cd TaskManager
   ./scripts/generate_xcodeproj.sh
   ```
3. Run locally from Xcode (`TaskManager` scheme, `My Mac`).

## 3) Local archive test (unsigned)
Use this to verify archive/app structure quickly:
```bash
cd TaskManager
./scripts/archive_macos_app.sh
```
Output:
- `build/TaskManager.xcarchive`
- `build/TaskManager.xcarchive/Products/Applications/TaskManager.app`

## 4) Release archive (signed)
Before archive, update version/build in Xcode target (General tab):
- **Version** (Marketing Version)
- **Build** (Current Project Version)

Create signed archive:
```bash
cd TaskManager
xcodebuild -project TaskManagerApp.xcodeproj -scheme TaskManager -configuration Release -destination "generic/platform=macOS" -archivePath ../build/TaskManager-signed.xcarchive archive
```
Output:
- `build/TaskManager-signed.xcarchive`

## 5) Upload to App Store Connect
1. Open **Xcode → Window → Organizer**.
2. Select latest signed archive.
3. Click **Distribute App → App Store Connect → Upload**.
4. Wait for processing in App Store Connect.

## 6) App Store Connect checklist each release
- New app version created (if needed).
- Release notes entered.
- Screenshots and metadata updated.
- Privacy details / export compliance updated if required.
- Submit for review.
