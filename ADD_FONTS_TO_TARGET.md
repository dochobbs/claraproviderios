# Add Fonts to Target - Step by Step

The question marks mean the fonts aren't added to the target. Here's how to fix it:

## Method 1: File Inspector (Easiest)

1. **Select both font files** in Project Navigator:
   - `RethinkSans-Regular.ttf`
   - `RethinkSans-Bold.ttf`
   - (Hold ⌘ to select multiple)

2. **Open File Inspector**:
   - Press ⌥⌘1 (Option + Command + 1)
   - OR click the right sidebar icon
   - OR View → Inspectors → File

3. **Check Target Membership**:
   - In the File Inspector, find "Target Membership" section
   - Check the box next to **"clara-provider-app"**
   - The question marks should disappear

4. **Clean and Build**:
   - Product → Clean Build Folder (⇧⌘K)
   - Product → Build (⌘B)

## Method 2: Add Files Dialog

If Method 1 doesn't work:

1. **Right-click** on the "clara-provider-app" folder in Project Navigator
2. Select **"Add Files to 'clara-provider-app'..."**
3. Navigate to and select both `.ttf` files
4. **IMPORTANT**: Check these boxes:
   - ✅ "Copy items if needed" (may already be grayed out)
   - ✅ "Create groups" (not "Create folder references")
   - ✅ "Add to targets: clara-provider-app" (MUST be checked)
5. Click **"Add"**

## Method 3: Build Phases

1. Select the **project** (blue icon) in Project Navigator
2. Select **"clara-provider-app"** target
3. Go to **"Build Phases"** tab
4. Expand **"Copy Bundle Resources"**
5. Click the **"+"** button
6. Add both `RethinkSans-Regular.ttf` and `RethinkSans-Bold.ttf`

## Verify It Worked

After adding fonts:
- Question marks should disappear
- Build the app
- Check console for: `✅ RethinkSans-Regular font loaded successfully`

