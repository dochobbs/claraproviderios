# App Icon Setup Instructions

## Quick Setup (Xcode Method)

1. **Prepare your icon:**
   - Size: 1024x1024 pixels
   - Format: PNG
   - No transparency
   - RGB color space

2. **Add in Xcode:**
   - Open `Assets.xcassets` folder
   - Click on `AppIcon`
   - Drag your 1024x1024 image into the slot
   - Xcode auto-generates all sizes

## Manual Setup

If you want to add files manually:

1. **Create icon files:**
   - `appicon-1024.png` (1024x1024) - Main icon
   - `appicon-dark-1024.png` (1024x1024) - Dark mode variant (optional)
   - `appicon-tinted-1024.png` (1024x1024) - Tinted variant (optional)

2. **Place files in:**
   ```
   clara-provider-app/Assets.xcassets/AppIcon.appiconset/
   ```

3. **Update Contents.json** to reference the files:
   ```json
   {
     "images" : [
       {
         "filename" : "appicon-1024.png",
         "idiom" : "universal",
         "platform" : "ios",
         "size" : "1024x1024"
       },
       {
         "filename" : "appicon-dark-1024.png",
         "appearances" : [
           {
             "appearance" : "luminosity",
             "value" : "dark"
           }
         ],
         "idiom" : "universal",
         "platform" : "ios",
         "size" : "1024x1024"
       },
       {
         "filename" : "appicon-tinted-1024.png",
         "appearances" : [
           {
             "appearance" : "luminosity",
             "value" : "tinted"
           }
         ],
         "idiom" : "universal",
         "platform" : "ios",
         "size" : "1024x1024"
       }
     ],
     "info" : {
       "author" : "xcode",
       "version" : 1
     }
   }
   ```

## Icon Design Guidelines

- **Size**: Exactly 1024x1024 pixels
- **Format**: PNG (recommended) or JPEG
- **No transparency**: iOS will reject icons with alpha channels
- **Corner radius**: iOS automatically applies rounded corners
- **Padding**: Keep important content away from edges (safe area ~10% from edges)
- **Design**: Should represent your app clearly at small sizes

## Testing

After adding your icon:
1. Clean build folder: Product → Clean Build Folder (⇧⌘K)
2. Build and run on simulator or device
3. Check the home screen to see your icon

## Troubleshooting

**Icon not showing:**
- Ensure the image is exactly 1024x1024
- Check file is in the correct location
- Clean build folder and rebuild
- Verify Contents.json references the correct filename

**Icon appears blurry:**
- Ensure source image is high resolution (1024x1024)
- Use PNG format for best quality
- Don't manually resize - let Xcode handle it

