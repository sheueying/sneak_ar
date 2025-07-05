# ShoeFit Application

A Flutter application with AR and ML features for foot measurement and virtual shoe try-on.

## Features

- AR foot measurement using computer vision
- Virtual shoe try-on with 3D models
- Product catalog and shopping cart
- User authentication and profiles
- Real-time chat and order management

## AR Foot Measurement Troubleshooting

### Common Issues and Solutions

#### 1. Camera Permission Issues
**Symptoms**: Camera fails to initialize or shows permission dialog
**Solutions**:
- Grant camera permission in device settings
- Restart the app after granting permissions
- Check if another app is using the camera

#### 2. ML Kit Initialization Problems
**Symptoms**: "Failed to initialize AR measurement system" error
**Solutions**:
- Ensure stable internet connection for model downloads
- Check device storage space (requires ~50MB for ML models)
- Restart the app to retry initialization
- Some older devices may not support all ML Kit features

#### 3. Calibration Issues
**Symptoms**: Calibration fails or measurement is inaccurate
**Solutions**:
- Use a clearly visible reference object (credit card, phone, etc.)
- Ensure good lighting conditions
- Hold the reference object steady during calibration
- Try different reference objects if one fails

#### 4. Foot Detection Problems
**Symptoms**: No foot detected or inaccurate measurements
**Solutions**:
- Remove socks and ensure clean feet
- Use a flat, hard surface (tile floor, wooden board)
- Ensure good lighting for accurate detection
- Position foot in the center of the measurement frame
- Hold still during measurement process

#### 5. UI Layout Issues
**Symptoms**: Screen overflow or layout problems
**Solutions**:
- The app automatically adjusts for different screen sizes
- Debug mode shows additional buttons that may cause overflow
- Test mode is available in debug builds for UI verification

### Debug Mode Features

When running in debug mode, additional features are available:

1. **Test Mode Button** (Orange bug icon): Bypasses calibration for testing
2. **Troubleshooting Dialog** (Wrench icon): Shows detailed diagnostic information
3. **Test Measurement** (Green play button): Simulates measurement with mock data

### Device Compatibility

**Minimum Requirements**:
- Android 6.0 (API level 23) or higher
- Camera with autofocus
- 2GB RAM minimum
- 100MB free storage space

**Recommended**:
- Android 8.0 (API level 26) or higher
- 4GB RAM or more
- Good lighting conditions
- Stable internet connection

### Performance Tips

1. **Close other apps** before using AR features
2. **Ensure good lighting** for accurate measurements
3. **Keep the device steady** during measurement
4. **Use a flat surface** for foot placement
5. **Allow model downloads** to complete before first use

### Error Codes and Meanings

- **Camera initialization failed**: Check permissions and device compatibility
- **ML Kit not available**: Check internet connection and device storage
- **Calibration failed**: Try different reference object or better lighting
- **No foot detected**: Improve lighting and foot positioning
- **Measurement timeout**: Ensure foot is clearly visible and hold still

### Getting Help

If you continue to experience issues:

1. Check the troubleshooting dialog in debug mode
2. Verify device compatibility requirements
3. Try the test mode to isolate UI vs. detection issues
4. Check console logs for detailed error messages
5. Ensure you're using the latest version of the app

## Installation

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Configure Firebase (see Firebase setup guide)
4. Run the app: `flutter run`

## Dependencies

- Flutter 3.0+
- Camera plugin
- Google ML Kit
- Firebase services
- Permission handler
- Model viewer for 3D models
