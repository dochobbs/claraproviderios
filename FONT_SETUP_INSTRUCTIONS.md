# Font Setup Instructions

## Problem
The custom fonts (RethinkSans-Regular and RethinkSans-Bold) are not included in the app bundle, causing text to not display properly when the app is installed.

## Solution

### Option 1: Add Fonts to Project (Recommended)

1. **Copy font files from patient app:**
   - Copy `RethinkSans-Regular.ttf` from `GIT/vhs/clara-app/ClaraApp/`
   - Copy `RethinkSans-Bold.ttf` from `GIT/vhs/clara-app/ClaraApp/`

2. **Add to Xcode project:**
   - Open the provider app project in Xcode
   - Right-click on the "Clara Provider" folder in Project Navigator
   - Select "Add Files to 'Clara Provider'..."
   - Navigate to and select both `.ttf` files
   - **IMPORTANT**: Check "Copy items if needed" and ensure "Clara Provider" target is checked
   - Click "Add"

3. **Register fonts in Info.plist:**
   - In Xcode, select the project in Project Navigator
   - Select "Clara Provider" target
   - Go to "Info" tab
   - Expand "Custom iOS Target Properties"
   - Add a new key: `Fonts provided by application` (or `UIAppFonts`)
   - Add two items:
     - `RethinkSans-Regular.ttf`
     - `RethinkSans-Bold.ttf`

   **OR** add to build settings:
   - Go to Build Settings
   - Search for "Info.plist"
   - Add: `INFOPLIST_KEY_UIAppFonts = ("RethinkSans-Regular.ttf", "RethinkSans-Bold.ttf")`

4. **Verify font names:**
   - The font names used in code must match the PostScript names in the font files
   - Current code uses: "RethinkSans-Regular" and "RethinkSans-Bold"
   - If these don't match, update `FontExtensions.swift`

### Option 2: Use Assets Catalog (Like Patient App)

The patient app uses an Assets Catalog approach:

1. **Create font datasets in Assets.xcassets:**
   - Right-click on `Assets.xcassets`
   - Select "New Data Set"
   - Name it `RethinkSans-Regular`
   - Drag `RethinkSans-Regular.ttf` into it
   - Repeat for `RethinkSans-Bold`

2. **Update FontExtensions.swift** to load from assets (more complex, but matches patient app approach)

### Option 3: Use System Fonts (Current Fallback)

The code now falls back to system fonts if custom fonts aren't available. This ensures text is always visible, but won't match the patient app's exact typography.

## Verification

After adding fonts:

1. Clean build folder: Product → Clean Build Folder (⇧⌘K)
2. Build and run on device
3. Check that text appears correctly
4. Verify fonts are actually being used (they should look different from system fonts)

## Troubleshooting

**Text still not showing:**
- Verify fonts are added to the target (Target Membership)
- Check Info.plist entries are correct
- Ensure font file names match exactly (case-sensitive)
- Try rebuilding from scratch

**Fonts not loading:**
- Verify PostScript names match (use Font Book app to check)
- Check font files are in the correct location
- Ensure fonts are included in app bundle (check Build Phases → Copy Bundle Resources)

