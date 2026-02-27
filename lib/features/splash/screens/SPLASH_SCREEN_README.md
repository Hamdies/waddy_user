# Waddi Animated Splash Screen

## Overview
This is a beautiful, animated splash screen inspired by the Wise app's splash animation. It features smooth track animations, expanding circles, and elegant transitions.

## Features
- **Track Animation**: A vertical track that animates from bottom to top
- **Expanding Circle**: A circular element that expands and moves with the track
- **Background Reveal**: A gradient background that reveals as the animation progresses
- **Smooth Transitions**: All animations use carefully tuned easing curves
- **Fade Out**: The entire splash screen fades out at the end

## Animation Timeline (1265ms total)

### Phase 1: Back Track (0-435ms)
- A dark green track starts appearing from the bottom
- Progress: 0% to 31% of screen height

### Phase 2: Front Track Progress (0-875ms)
- The main track with gradient background starts moving up
- Progress: 0% to 100% (bottom to top)

### Phase 3: Front Track Expansion (450-990ms)
- The track width expands from initial width to full screen width
- Creates a dramatic reveal effect

### Phase 4: Circle Head Expansion (475-875ms)
- The circular element at the top of the track expands
- Diameter increases from 102px to 132px

### Phase 5: Fade Out (1050-1265ms)
- The entire splash screen fades out smoothly

## Customization

### Colors
You can customize the brand colors in `waddi_animated_splash_screen.dart`:

```dart
// Line 28-30
const _primaryColor = Color(0xFF4CAF50); // Main brand color (green)
const _darkColor = Color(0xFF1B5E20); // Dark accent color
const _backgroundColor = Color(0xFFF1F8E9); // Light background
```

### Logo
The logo is displayed in the center during the animation. Update the path in the `_Background` widget:

```dart
// Line 100-104
Image.asset(
  'assets/image/logo_no_bg.png', // Change this path
  height: 90,
  width: 90,
),
```

### Icon in Circle
The shopping bag icon in the expanding circle can be customized in the `_CirclePainter` class (lines 345-375). You can:
- Change the icon shape
- Modify the stroke width
- Update the icon color

### Animation Duration
To change the overall animation speed, modify:

```dart
// Line 7
const _animationDuration = 1265; // Duration in milliseconds
```

### Animation Timing
Fine-tune individual animation phases by adjusting these constants (lines 9-21):
- `_fadeTransitionStart` / `_fadeTransitionEnd`: When fade out begins/ends
- `_frontTrackProgressStart` / `_frontTrackProgressEnd`: Track movement timing
- `_frontTrackExpansionStart` / `_frontTrackExpansionEnd`: Width expansion timing
- `_frontTrackHeadExpansionStart` / `_frontTrackHeadExpansionEnd`: Circle growth timing
- `_backTrackProgressStart` / `_backTrackProgressEnd`: Background track timing

### Track Dimensions
Adjust the initial and final sizes:

```dart
// Lines 23-25
const _initialTrackWidth = 112.0; // Starting width
const _initialTrackHeadDiameter = 102.0; // Starting circle size
const _finalTrackHeadDiameter = 132.0; // Ending circle size
```

## Usage

The splash screen is already integrated into your main `SplashScreen` widget. The animation automatically starts when the splash screen is displayed and plays once.

### Integration Points
1. **Animation Controller**: Created in `SplashScreenState.initState()`
2. **Auto-start**: Animation starts with `_animationController.forward()`
3. **Cleanup**: Controller is disposed in `dispose()` method

## Technical Details

### Performance Optimizations
- Uses `RepaintBoundary` widgets to isolate repainting
- Efficient `CustomPainter` implementations
- Smooth 60fps animations with proper curve functions

### Widget Structure
```
WaddiAnimatedSplashScreen
├── FadeTransition (fade out effect)
    └── Stack
        ├── _Background (logo on solid color)
        └── _Foreground
            ├── _TrackPainter (dark background track)
            ├── ClipPath with _Clipper (gradient reveal)
            └── _CirclePainter (expanding circle with icon)
```

### Key Components
- **_Track**: Calculates the track path and position
- **_TrackPainter**: Paints the background track
- **_Clipper**: Clips the gradient background to reveal it progressively
- **_Delegate**: Positions the expanding circle
- **_CirclePainter**: Draws the circle and icon

## Tips for Customization

1. **Test on Real Devices**: Animations may look different on actual devices vs simulators
2. **Adjust Curves**: Experiment with different easing curves for different feels
3. **Color Contrast**: Ensure good contrast between logo and background colors
4. **Icon Simplicity**: Keep the circle icon simple for best visual impact
5. **Duration Balance**: Too fast feels rushed, too slow feels sluggish (1-2 seconds is ideal)

## Troubleshooting

### Animation Not Playing
- Check that the controller is properly initialized
- Ensure `forward()` is called in `initState()`
- Verify the widget is being rebuilt

### Performance Issues
- Reduce animation duration
- Simplify custom painters
- Check for unnecessary rebuilds

### Visual Glitches
- Ensure proper use of `RepaintBoundary`
- Check z-order of Stack children
- Verify clip paths are calculated correctly

## Future Enhancements

Potential improvements you could add:
- Add sound effects
- Include particle effects
- Add logo animation (rotation, scale, etc.)
- Implement different animation styles based on theme
- Add loading progress indicator
