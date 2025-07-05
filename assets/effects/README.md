# DeepAR Shoe Try-On Effects

This directory contains DeepAR effects for virtual shoe try-on functionality.

## Getting Real DeepAR Effects

### 1. Free Filter Pack
Download the free DeepAR filter pack from: https://docs.deepar.ai/deepar-sdk/filters

### 2. DeepAR Asset Store
Visit the DeepAR Asset Store for professional shoe try-on effects: https://www.store.deepar.ai/

### 3. Create Custom Effects
Use DeepAR Studio to create custom shoe try-on effects: https://docs.deepar.ai/deepar-sdk/studio

## Effect Files Structure

Place your `.deepar` effect files in this directory:

```
assets/effects/
├── nike_air_force_1.deepar
├── adidas_ultraboost.deepar
├── adidas_yeezy_boost.deepar
├── gazelle.deepar
├── basic_face.deepar
├── body_tracking.deepar
└── object_placement.deepar
```

## Shoe Try-On Effect Types

### 1. Foot Tracking Effects
- Track foot position and size
- Place 3D shoes on feet
- Real-time size adjustment

### 2. Body Tracking Effects
- Full body pose estimation
- Shoe placement on feet
- Walking/running animations

### 3. Object Placement Effects
- Place shoes in environment
- AR furniture try-on
- Virtual showroom experience

## Integration

The effects are automatically loaded by the DeepAR service when users select shoes in the app.

## Testing

1. Download sample effects from DeepAR's free pack
2. Place `.deepar` files in this directory
3. Update `pubspec.yaml` to include the effects
4. Test in the AR camera screen 