# Fix Font Question Marks in Xcode

The fonts are showing question marks because they need to be explicitly added to the target.

## Quick Fix in Xcode:

1. **Select both font files** in the Project Navigator (`RethinkSans-Regular.ttf` and `RethinkSans-Bold.ttf`)

2. **Open the File Inspector** (right panel, or press ⌥⌘1)

3. **Under "Target Membership"**, make sure **"clara-provider-app"** is checked ✅

4. **Clean and rebuild** (Product → Clean Build Folder, then Product → Build)

## Alternative: Move fonts to a Resources folder

If the above doesn't work, you can create a Resources folder:

1. Right-click on "clara-provider-app" folder in Project Navigator
2. Select "New Group" → name it "Resources"
3. Drag the two `.ttf` files into the Resources folder
4. Make sure Target Membership is checked

## Verify fonts are included:

After rebuilding, run the app and check the console. You should see:
- `✅ RethinkSans-Regular.ttf found in bundle at: ...`
- `✅ RethinkSans-Bold.ttf found in bundle at: ...`

If you still see `❌ NOT found in bundle`, the fonts aren't being copied to the app bundle.

