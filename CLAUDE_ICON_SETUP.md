# Claude Icon Setup Instructions

## Quick Setup

1. **Open Xcode** and navigate to your project
2. **Find the asset catalog**: `clara-provider-app/Assets.xcassets/ClaudeIcon.imageset/`
3. **Add your image**:
   - Option A: Drag your image file directly into the `ClaudeIcon.imageset` folder in Finder
   - Option B: In Xcode, click on `ClaudeIcon` in the asset catalog, then drag your image into the 1x slot

4. **Image file naming**: Name it `claude-icon.png` (or update `Contents.json` to match your filename)

## Image Requirements

- **Format**: PNG (recommended) or JPEG
- **Size**: At least 24x24 points (48x48 pixels @2x, 72x72 pixels @3x)
- **For best results**: Provide a single high-resolution image (72x72 or larger) - iOS will scale it automatically

## Alternative: Use SF Symbol Instead

If you prefer to use a system icon instead, you can change the button code to use any SF Symbol like:
- `sparkles` (current fallback)
- `bubble.left.and.bubble.right.fill`
- `message.fill`
- `brain.head.profile`

## Troubleshooting

If the icon doesn't appear:
1. Make sure the image file is actually in the `ClaudeIcon.imageset` folder
2. Check that the filename in `Contents.json` matches your actual file name
3. Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)
4. Rebuild the app

