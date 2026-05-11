// Color blindness transformation matrices
// Each matrix transforms RGB values to simulate different types of color vision deficiency
static const float3x3 color_blindness_matrices[7] =
{
    // Mode 0: None (identity matrix)
    float3x3(
        1.00000, 0.00000, 0.00000,
        0.00000, 1.00000, 0.00000,
        0.00000, 0.00000, 1.00000
    ),

    // Mode 1: Protanopia (Red-Blind - missing L-cones)
    float3x3(
        0.56667, 0.43333, 0.00000,
        0.55833, 0.44167, 0.00000,
        0.00000, 0.24167, 0.75833
    ),

    // Mode 2: Deuteranopia (Green-Blind - missing M-cones)
    float3x3(
        0.62500, 0.37500, 0.00000,
        0.70000, 0.30000, 0.00000,
        0.00000, 0.30000, 0.70000
    ),

    // Mode 3: Tritanopia (Blue-Blind - missing S-cones)
    float3x3(
        0.95000, 0.05000, 0.00000,
        0.00000, 0.43333, 0.56667,
        0.00000, 0.47500, 0.52500
    ),

    // Mode 4: Protanomaly (Red-Weak - weak L-cones)
    float3x3(
        0.81667, 0.18333, 0.00000,
        0.33333, 0.66667, 0.00000,
        0.00000, 0.12500, 0.87500
    ),

    // Mode 5: Deuteranomaly (Green-Weak - weak M-cones)
    float3x3(
        0.80000, 0.20000, 0.00000,
        0.25833, 0.74167, 0.00000,
        0.00000, 0.14167, 0.85833
    ),

    // Mode 6: Tritanomaly (Blue-Weak - weak S-cones)
    float3x3(
        0.96667, 0.03333, 0.00000,
        0.00000, 0.73333, 0.26667,
        0.00000, 0.18333, 0.81667
    )
};

float3 apply_color_blindness(float3 rgb, uint mode)
{
    // Clamp mode to valid range
    mode = min(mode, 6);

    // Apply transformation matrix
    return mul(color_blindness_matrices[mode], rgb);
}
