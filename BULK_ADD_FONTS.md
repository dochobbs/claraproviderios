# Bulk Add Fonts to Target - Quick Fix

Since you've added multiple fonts and they all have question marks, here's the easiest way to fix them all at once:

## Method 1: Select All Fonts at Once (Fastest)

1. **In Xcode Project Navigator**, expand the "Clara Provider" folder
2. **Select ALL font files**:
   - Click the first `.ttf` file
   - Hold **⇧Shift** and click the last `.ttf` file (this selects all in between)
   - OR hold **⌘Command** and click each `.ttf` file individually
3. **Open File Inspector**: Press **⌥⌘1** (Option + Command + 1)
4. **Check Target Membership**: In the File Inspector, find "Target Membership" section
5. **Check the box** next to **"Clara Provider"** (this applies to ALL selected files)
6. **Clean and Build**: Product → Clean Build Folder (⇧⌘K), then Product → Build (⌘B)

All question marks should disappear!

## Method 2: Add via Build Phases

1. Select the **project** (blue icon) in Project Navigator
2. Select **"Clara Provider"** target
3. Go to **"Build Phases"** tab
4. Expand **"Copy Bundle Resources"**
5. Click the **"+"** button
6. In the file picker, navigate to "Clara Provider" folder
7. **Select ALL `.ttf` files** (⌘A or ⌘+click each)
8. Click **"Add"**

## Verify

After adding fonts:
- Question marks should disappear
- Build the app
- Check console for font loading messages

