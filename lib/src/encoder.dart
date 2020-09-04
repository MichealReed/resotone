// Core Dependencies
import 'dart:web_audio';
import 'dart:math';

// Internal Dependencies
import "tables.dart" as Tables;
import 'reso_utils.dart';

/// Spatially encodes input using weighted spherical harmonics.
class Encoder {
// [context]
// [options]
// [options.ambisonicOrder]
// Desired ambisonic order. Defaults to
// [ResoUtils.DEFAULT_AMBISONIC_ORDER DEFAULT_AMBISONIC_ORDER].
// [options.azimuth]
// Azimuth (in degrees). Defaults to
// [ResoUtils.DEFAULT_AZIMUTH DEFAULT_AZIMUTH].
// [options.elevation]
// Elevation (in degrees). Defaults to
// [ResoUtils.DEFAULT_ELEVATION DEFAULT_ELEVATION].
// [options.sourceWidth]
// Source width (in degrees). Where 0 degrees is a ponum source and 360 degrees
// is an omnidirectional source. Defaults to
// [ResoUtils.DEFAULT_SOURCE_WIDTH DEFAULT_SOURCE_WIDTH].
  Encoder(AudioContext context, Map<String, dynamic> options) {
    // Use defaults for null arguments.
    if (options == null) {
      options = {};
    }
    if (options['ambisonicOrder'] == null) {
      options['ambisonicOrder'] = ResoUtils.DEFAULT_AMBISONIC_ORDER;
    }
    if (options['azimuth'] == null) {
      options['azimuth'] = ResoUtils.DEFAULT_AZIMUTH;
    }
    if (options['elevation'] == null) {
      options['elevation'] = ResoUtils.DEFAULT_ELEVATION;
    }
    if (options['sourceWidth'] == null) {
      options['sourceWidth'] = ResoUtils.DEFAULT_SOURCE_WIDTH;
    }

    _context = context;

    // Create I/O nodes.
    input = context.createGain();
    _channelGain = List<GainNode>();
    output = context.createGain();

    // Set initial order, angle and source width.
    setAmbisonicOrder(options['ambisonicOrder']);
    _azimuth = options['azimuth'];
    _elevation = options['elevation'];
    setSourceWidth(options['sourceWidth']);
  }

  AudioContext _context;
  GainNode input;
  GainNode output;
  List<GainNode> _channelGain;
  ChannelMergerNode _merger = null;
  num _azimuth;
  num _elevation;
  num _ambisonicOrder;
  num _spreadIndex;

  /// Set the desired ambisonic order.
  ///  ambisonicOrder Desired ambisonic order.
  setAmbisonicOrder(num ambisonicOrder) {
    _ambisonicOrder = validateAmbisonicOrder(ambisonicOrder);

    input.disconnect();
    for (num i = 0; i < _channelGain.length; i++) {
      _channelGain[i].disconnect();
    }
    if (_merger != null) {
      _merger.disconnect();
    }
    _channelGain = null;
    _merger = null;

    // Create audio graph.
    num numChannels = ((_ambisonicOrder + 1) * (_ambisonicOrder + 1));
    _merger = _context.createChannelMerger(numChannels);
    _channelGain = new List(numChannels);
    for (num i = 0; i < numChannels; i++) {
      _channelGain[i] = _context.createGain();
      input.connectNode(_channelGain[i]);
      _channelGain[i].connectNode(_merger, 0, i);
    }
    _merger.connectNode(output);
  }

  /// Set the direction of the encoded source signal.
  /// [azimuth]
  /// Azimuth (in degrees). Defaults to
  /// [ResoUtils.DEFAULT_AZIMUTH DEFAULT_AZIMUTH].
  /// [elevation]
  /// Elevation (in degrees). Defaults to
  /// [ResoUtils.DEFAULT_ELEVATION DEFAULT_ELEVATION].
  setDirection(num azimuth, num elevation) {
    // Format input direction to nearest indices.
    if (azimuth == null) {
      azimuth = ResoUtils.DEFAULT_AZIMUTH;
    }
    if (elevation == null) {
      elevation = ResoUtils.DEFAULT_ELEVATION;
    }

    // Store the formatted input (for updating source width).
    _azimuth = azimuth;
    _elevation = elevation;

    // Format direction for index lookups.
    azimuth = (azimuth % 360).round();
    if (azimuth < 0) {
      azimuth += 360;
    }
    elevation = ((min(90, max(-90, elevation))) + 90).round();

    // Assign gains to each output.
    _channelGain[0].gain.value = Tables.MAX_RE_WEIGHTS[_spreadIndex][0];
    for (num i = 1; i <= _ambisonicOrder; i++) {
      num degreeWeight = Tables.MAX_RE_WEIGHTS[_spreadIndex][i];
      for (num j = -i; j <= i; j++) {
        num acnChannel = (i * i) + i + j;
        num elevationIndex = (i * (i + 1) / 2 + (j).abs() - 1);
        num val = Tables.SPHERICAL_HARMONICS[1][elevation][elevationIndex];
        if (j != 0) {
          num azimuthIndex = (Tables.SPHERICAL_HARMONICS_MAX_ORDER + j - 1);
          if (j < 0) {
            azimuthIndex = Tables.SPHERICAL_HARMONICS_MAX_ORDER + j;
          }
          val *= Tables.SPHERICAL_HARMONICS[0][azimuth][azimuthIndex];
        }
        _channelGain[acnChannel].gain.value = val * degreeWeight;
      }
    }
  }

  /// Set the source width (in degrees). Where 0 degrees is a ponum source and 360
  /// degrees is an omnidirectional source.
  /// [sourceWidth] (in degrees).
  setSourceWidth(num sourceWidth) {
    // The MAX_RE_WEIGHTS is a 360 x (Tables.SPHERICAL_HARMONICS_MAX_ORDER+1)
    // size table.
    _spreadIndex = min(359, max(0, sourceWidth.round()));
    setDirection(_azimuth, _elevation);
  }

  /// Validate the provided ambisonic order.
  /// [ambisonicOrder] Desired ambisonic order.
  /// return Validated/adjusted ambisonic order.
  static num validateAmbisonicOrder(num ambisonicOrder) {
    if (ambisonicOrder == null) {
      print('Error: Invalid ambisonic order' +
          ambisonicOrder.toString() +
          '\nUsing ambisonicOrder=1 instead.');
      ambisonicOrder = 1;
    } else if (ambisonicOrder < 1) {
      print('Error: Unable to render ambisonic order' +
          ambisonicOrder.toString() +
          '(Min order is 1)' +
          '\nUsing min order instead.');
      ambisonicOrder = 1;
    } else if (ambisonicOrder > Tables.SPHERICAL_HARMONICS_MAX_ORDER) {
      print('Error: Unable to render ambisonic order' +
          ambisonicOrder.toString() +
          '(Max order is' +
          Tables.SPHERICAL_HARMONICS_MAX_ORDER.toString() +
          ')\nUsing max order instead.');
      ambisonicOrder = Tables.SPHERICAL_HARMONICS_MAX_ORDER;
    }
    return ambisonicOrder;
  }
}
