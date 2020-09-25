// Core Dependencies
import 'dart:math';

bool resoDebug = false;

/// Resonance utility class for defaults and helper methods
class ResoUtils {
  ResoUtils();

  /// Default input gain (linear).
  static num DEFAULT_SOURCE_GAIN = 1;

  /// Maximum outside-the-room distance to attenuate far-field listener by.

  static num LISTENER_MAX_OUTSIDE_ROOM_DISTANCE = 1;

  /// Maximum outside-the-room distance to attenuate far-field sources by.

  static num SOURCE_MAX_OUTSIDE_ROOM_DISTANCE = 1;

  /// Default distance from listener when setting angle.
  static num DEFAULT_SOURCE_DISTANCE = 1;

  static List<num> DEFAULT_POSITION = [0, 0, 0];

  static List<num> DEFAULT_FORWARD = [0, 0, -1];

  static List<num> DEFAULT_UP = [0, 1, 0];

  static List<num> DEFAULT_RIGHT = [1, 0, 0];

  static num DEFAULT_SPEED_OF_SOUND = 343;

  /// Rolloff models (e.g. 'logarithmic', 'linear', or 'none').

  static List<String> ATTENUATION_ROLLOFFS = ['logarithmic', 'linear', 'none'];

  /// Default rolloff model ('logarithmic').
  static String DEFAULT_ATTENUATION_ROLLOFF = 'logarithmic';

  static num DEFAULT_MIN_DISTANCE = 1;

  static num DEFAULT_MAX_DISTANCE = 1000;

  /// The default alpha (i.e. microphone pattern).
  static num DEFAULT_DIRECTIVITY_ALPHA = 0;

  /// The default pattern sharpness (i.e. pattern exponent).
  static num DEFAULT_DIRECTIVITY_SHARPNESS = 1;

  /// Default azimuth (in degrees). Suitable range is 0 to 360.
  static num DEFAULT_AZIMUTH = 0;

  /// Default elevation (in degres).
  /// Suitable range is from -90 (below) to 90 (above).
  static num DEFAULT_ELEVATION = 0;

  /// The default ambisonic order.
  static num DEFAULT_AMBISONIC_ORDER = 1;

  /// The default source width.
  static num DEFAULT_SOURCE_WIDTH = 0;

  /// The maximum delay (in seconds) of a single wall reflection.
  static num DEFAULT_REFLECTION_MAX_DURATION = 0.5;

  /// The -12dB cutoff frequency (in Hertz) for the lowpass filter applied to
  /// all reflections.
  static num DEFAULT_REFLECTION_CUTOFF_FREQUENCY = 6400; // Uses -12dB cutoff.

  /// The default reflection coefficients (where 0 = no reflection, 1 = perfect
  /// reflection, -1 = mirrored reflection (180-degrees out of phase)).
  static Map<String, dynamic> DEFAULT_REFLECTION_COEFFICIENTS = {
    "left": 0,
    "right": 0,
    "front": 0,
    "back": 0,
    "down": 0,
    "up": 0,
  };

  /// The minimum distance we consider the listener to be to any given wall.
  static num DEFAULT_REFLECTION_MIN_DISTANCE = 1;

  /// Default room dimensions (in meters).
  static Map<String, dynamic> DEFAULT_ROOM_DIMENSIONS = {
    "width": 0,
    "height": 0,
    "depth": 0,
  };

  /// The multiplier to apply to distances from the listener to each wall.
  static num DEFAULT_REFLECTION_MULTIPLIER = 1;

  /// The default bandwidth (in octaves) of the center frequencies.
  static num DEFAULT_REVERB_BANDWIDTH = 1;

  /// The default multiplier applied when computing tail lengths.
  static num DEFAULT_REVERB_DURATION_MULTIPLIER = 1;

  /// The late reflections pre-delay (in milliseconds).
  static num DEFAULT_REVERB_PREDELAY = 1.5;

  /// The length of the beginning of the impulse response to apply a
  /// half-Hann window to.
  static num DEFAULT_REVERB_TAIL_ONSET = 3.8;

  /// The default gain (linear).
  static num DEFAULT_REVERB_GAIN = 0.01;

  /// The maximum impulse response length (in seconds).

  static num DEFAULT_REVERB_MAX_DURATION = 3;

  /// Center frequencies of the multiband late reflections.
  /// Nine bands are computed by: 31.25 /// 2^(0:8).
  static List<num> DEFAULT_REVERB_FREQUENCY_BANDS = [
    31.25,
    62.5,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
  ];

  /// The number of frequency bands.
  static num NUMBER_REVERB_FREQUENCY_BANDS =
      DEFAULT_REVERB_FREQUENCY_BANDS.length;

  /// The default multiband RT60 durations (in seconds).
  static List<num> DEFAULT_REVERB_DURATIONS =
      new List<num>(ResoUtils.NUMBER_REVERB_FREQUENCY_BANDS);

  /// Pre-defined frequency-dependent absorption coefficients for listed materials.
  /// Currently supported materials are:
  /// <ul>
  /// <li>'transparent'</li>
  /// <li>'acoustic-ceiling-tiles'</li>
  /// <li>'brick-bare'</li>
  /// <li>'brick-panumed'</li>
  /// <li>'concrete-block-coarse'</li>
  /// <li>'concrete-block-panumed'</li>
  /// <li>'curtain-heavy'</li>
  /// <li>'fiber-glass-insulation'</li>
  /// <li>'glass-thin'</li>
  /// <li>'glass-thick'</li>
  /// <li>'grass'</li>
  /// <li>'linoleum-on-concrete'</li>
  /// <li>'marble'</li>
  /// <li>'metal'</li>
  /// <li>'parquet-on-concrete'</li>
  /// <li>'plaster-smooth'</li>
  /// <li>'plywood-panel'</li>
  /// <li>'polished-concrete-or-tile'</li>
  /// <li>'sheetrock'</li>
  /// <li>'water-or-ice-surface'</li>
  /// <li>'wood-ceiling'</li>
  /// <li>'wood-panel'</li>
  /// <li>'uniform'</li>
  /// </ul>
  static Map<String, List<num>> ROOM_MATERIAL_COEFFICIENTS = {
    'transparent': [
      1.000,
      1.000,
      1.000,
      1.000,
      1.000,
      1.000,
      1.000,
      1.000,
      1.000
    ],
    'acoustic-ceiling-tiles': [
      0.672,
      0.675,
      0.700,
      0.660,
      0.720,
      0.920,
      0.880,
      0.750,
      1.000
    ],
    'brick-bare': [
      0.030,
      0.030,
      0.030,
      0.030,
      0.030,
      0.040,
      0.050,
      0.070,
      0.140
    ],
    'brick-panumed': [
      0.006,
      0.007,
      0.010,
      0.010,
      0.020,
      0.020,
      0.020,
      0.030,
      0.060
    ],
    'concrete-block-coarse': [
      0.360,
      0.360,
      0.360,
      0.440,
      0.310,
      0.290,
      0.390,
      0.250,
      0.500
    ],
    'concrete-block-panumed': [
      0.092,
      0.090,
      0.100,
      0.050,
      0.060,
      0.070,
      0.090,
      0.080,
      0.160
    ],
    'curtain-heavy': [
      0.073,
      0.106,
      0.140,
      0.350,
      0.550,
      0.720,
      0.700,
      0.650,
      1.000
    ],
    'fiber-glass-insulation': [
      0.193,
      0.220,
      0.220,
      0.820,
      0.990,
      0.990,
      0.990,
      0.990,
      1.000
    ],
    'glass-thin': [
      0.180,
      0.169,
      0.180,
      0.060,
      0.040,
      0.030,
      0.020,
      0.020,
      0.040
    ],
    'glass-thick': [
      0.350,
      0.350,
      0.350,
      0.250,
      0.180,
      0.120,
      0.070,
      0.040,
      0.080
    ],
    'grass': [0.050, 0.050, 0.150, 0.250, 0.400, 0.550, 0.600, 0.600, 0.600],
    'linoleum-on-concrete': [
      0.020,
      0.020,
      0.020,
      0.030,
      0.030,
      0.030,
      0.030,
      0.020,
      0.040
    ],
    'marble': [0.010, 0.010, 0.010, 0.010, 0.010, 0.010, 0.020, 0.020, 0.040],
    'metal': [0.030, 0.035, 0.040, 0.040, 0.050, 0.050, 0.050, 0.070, 0.090],
    'parquet-on-concrete': [
      0.028,
      0.030,
      0.040,
      0.040,
      0.070,
      0.060,
      0.060,
      0.070,
      0.140
    ],
    'plaster-rough': [
      0.017,
      0.018,
      0.020,
      0.030,
      0.040,
      0.050,
      0.040,
      0.030,
      0.060
    ],
    'plaster-smooth': [
      0.011,
      0.012,
      0.013,
      0.015,
      0.020,
      0.030,
      0.040,
      0.050,
      0.100
    ],
    'plywood-panel': [
      0.400,
      0.340,
      0.280,
      0.220,
      0.170,
      0.090,
      0.100,
      0.110,
      0.220
    ],
    'polished-concrete-or-tile': [
      0.008,
      0.008,
      0.010,
      0.010,
      0.015,
      0.020,
      0.020,
      0.020,
      0.040
    ],
    'sheet-rock': [
      0.290,
      0.279,
      0.290,
      0.100,
      0.050,
      0.040,
      0.070,
      0.090,
      0.180
    ],
    'water-or-ice-surface': [
      0.006,
      0.006,
      0.008,
      0.008,
      0.013,
      0.015,
      0.020,
      0.025,
      0.050
    ],
    'wood-ceiling': [
      0.150,
      0.147,
      0.150,
      0.110,
      0.100,
      0.070,
      0.060,
      0.070,
      0.140
    ],
    'wood-panel': [
      0.280,
      0.280,
      0.280,
      0.220,
      0.170,
      0.090,
      0.100,
      0.110,
      0.220
    ],
    'uniform': [0.500, 0.500, 0.500, 0.500, 0.500, 0.500, 0.500, 0.500, 0.500],
  };

  /// Default materials that use strings from
  /// [ResoUtils.MATERIAL_COEFFICIENTS MATERIAL_COEFFICIENTS]
  static Map<String, String> DEFAULT_ROOM_MATERIALS = {
    'left': 'transparent',
    'right': 'transparent',
    'front': 'transparent',
    'back': 'transparent',
    'down': 'transparent',
    'up': 'transparent',
  };

  /// The number of bands to average over when computing reflection coefficients.
  static num NUMBER_REFLECTION_AVERAGING_BANDS = 3;

  /// The starting band to average over when computing reflection coefficients.
  static num ROOM_STARTING_AVERAGING_BAND = 4;

  /// The minimum threshold for room volume.
  /// Room model is disabled if volume is below this value.
  static num ROOM_MIN_VOLUME = 1e-4;

  /// Air absorption coefficients per frequency band.
  static List<num> ROOM_AIR_ABSORPTION_COEFFICIENTS = [
    0.0006,
    0.0006,
    0.0007,
    0.0008,
    0.0010,
    0.0015,
    0.0026,
    0.0060,
    0.0207
  ];

  /// A scalar correction value to ensure Sabine and Eyring produce the same RT60
  /// value at the cross-over threshold.
  static num ROOM_EYRING_CORRECTION_COEFFICIENT = 1.38;

  static num TWO_PI = 6.28318530717959;

  static num TWENTY_FOUR_LOG10 = 55.2620422318571;

  static num LOG1000 = 6.90775527898214;

  static num LOG2_DIV2 = 0.346573590279973;

  static num DEGREES_TO_RADIANS = 0.017453292519943;

  static num RADIANS_TO_DEGREES = 57.295779513082323;

  static num EPSILON_FLOAT = 1e-8;

  /// Normalize a 3-d vector.
  /// [v] 3-element vector.
  /// return 3-element vector.
  static List<num> normalizeVector(List<num> v) {
    num n = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (n > EPSILON_FLOAT) {
      n = 1 / n;
      v[0] *= n;
      v[1] *= n;
      v[2] *= n;
    }
    return v;
  }

  /// Cross-product between two 3-d vectors.
  ///   [a] 3-element vector.
  ///   [b] 3-element vector.

  static List<num> crossProduct(List<num> a, List<num> b) {
    return [
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0],
    ];
  }

  static num sinh(num angle) {
    return (exp(angle) - exp(-angle)) / 2;
  }
}
