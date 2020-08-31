import "tables.dart" as Tables;
import 'reso_utils.dart';
import 'dart:web_audio';
import 'dart:math';

/**
 * @class Encoder
 * @description Spatially encodes input using weighted spherical harmonics.
 * @param {AudioContext} context
 * Associated {@link
https://developer.mozilla.org/en-US/docs/Web/API/AudioContext AudioContext}.
 * @param {Object} options
 * @param {Number} options.ambisonicOrder
 * Desired ambisonic order. Defaults to
 * {@linkcode ResoUtils.DEFAULT_AMBISONIC_ORDER DEFAULT_AMBISONIC_ORDER}.
 * @param {Number} options.azimuth
 * Azimuth (in degrees). Defaults to
 * {@linkcode ResoUtils.DEFAULT_AZIMUTH DEFAULT_AZIMUTH}.
 * @param {Number} options.elevation
 * Elevation (in degrees). Defaults to
 * {@linkcode ResoUtils.DEFAULT_ELEVATION DEFAULT_ELEVATION}.
 * @param {Number} options.sourceWidth
 * Source width (in degrees). Where 0 degrees is a ponum source and 360 degrees
 * is an omnidirectional source. Defaults to
 * {@linkcode ResoUtils.DEFAULT_SOURCE_WIDTH DEFAULT_SOURCE_WIDTH}.
 */
class Encoder {
  // Public variables.
  /**
   * Mono (1-channel) input {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} input
   * @memberof Encoder
   * @instance
   */
  /**
   * Ambisonic (multichannel) output {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} output
   * @memberof Encoder
   * @instance
   */

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

    this._context = context;

    // Create I/O nodes.
    this.input = context.createGain();
    this._channelGain = List<GainNode>();
    this.output = context.createGain();

    // Set initial order, angle and source width.
    this.setAmbisonicOrder(options['ambisonicOrder']);
    this._azimuth = options['azimuth'];
    this._elevation = options['elevation'];
    this.setSourceWidth(options['sourceWidth']);
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

/**
 * Set the desired ambisonic order.
 * @param {Number} ambisonicOrder Desired ambisonic order.
 */
  setAmbisonicOrder(num ambisonicOrder) {
    _ambisonicOrder = validateAmbisonicOrder(ambisonicOrder);

    this.input.disconnect();
    for (num i = 0; i < this._channelGain.length; i++) {
      this._channelGain[i].disconnect();
    }
    if (this._merger != null) {
      this._merger.disconnect();
    }
    _channelGain = null;
    _merger = null;

    // Create audio graph.
    num numChannels = ((_ambisonicOrder + 1) * (_ambisonicOrder + 1));
    this._merger = this._context.createChannelMerger(numChannels);
    this._channelGain = new List(numChannels);
    for (num i = 0; i < numChannels; i++) {
      this._channelGain[i] = this._context.createGain();
      this.input.connectNode(this._channelGain[i]);
      this._channelGain[i].connectNode(this._merger, 0, i);
    }
    this._merger.connectNode(this.output);
  }

/**
 * Set the direction of the encoded source signal.
 * @param {Number} azimuth
 * Azimuth (in degrees). Defaults to
 * {@linkcode ResoUtils.DEFAULT_AZIMUTH DEFAULT_AZIMUTH}.
 * @param {Number} elevation
 * Elevation (in degrees). Defaults to
 * {@linkcode ResoUtils.DEFAULT_ELEVATION DEFAULT_ELEVATION}.
 */
  setDirection(num azimuth, num elevation) {
    // Format input direction to nearest indices.
    if (azimuth == null) {
      azimuth = ResoUtils.DEFAULT_AZIMUTH;
    }
    if (elevation == null) {
      elevation = ResoUtils.DEFAULT_ELEVATION;
    }

    // Store the formatted input (for updating source width).
    this._azimuth = azimuth;
    this._elevation = elevation;

    // Format direction for index lookups.
    azimuth = (azimuth % 360).round();
    if (azimuth < 0) {
      azimuth += 360;
    }
    elevation = ((min(90, max(-90, elevation))) + 90).round();

    // Assign gains to each output.
    this._channelGain[0].gain.value =
        Tables.MAX_RE_WEIGHTS[this._spreadIndex][0];
    for (num i = 1; i <= _ambisonicOrder; i++) {
      num degreeWeight = Tables.MAX_RE_WEIGHTS[this._spreadIndex][i];
      for (num j = -i; j <= i; j++) {
        num acnChannel = (i * i) + i + j;
        num elevationIndex = (i * (i + 1) / 2 + (j).abs() - 1);
        num val =
            Tables.SPHERICAL_HARMONICS[1][elevation][elevationIndex];
        if (j != 0) {
          num azimuthIndex =
              (Tables.SPHERICAL_HARMONICS_MAX_ORDER + j - 1);
          if (j < 0) {
            azimuthIndex = Tables.SPHERICAL_HARMONICS_MAX_ORDER + j;
          }
          val *= Tables.SPHERICAL_HARMONICS[0][azimuth][azimuthIndex];
        }
        this._channelGain[acnChannel].gain.value = val * degreeWeight;
      }
    }
  }

/**
 * Set the source width (in degrees). Where 0 degrees is a ponum source and 360
 * degrees is an omnidirectional source.
 * @param {Number} sourceWidth (in degrees).
 */
  setSourceWidth(num sourceWidth) {
    // The MAX_RE_WEIGHTS is a 360 x (Tables.SPHERICAL_HARMONICS_MAX_ORDER+1)
    // size table.
    this._spreadIndex = min(359, max(0, sourceWidth.round()));
    this.setDirection(this._azimuth, this._elevation);
  }

/**
 * Validate the provided ambisonic order.
 * @param {Number} ambisonicOrder Desired ambisonic order.
 * @return {Number} Validated/adjusted ambisonic order.
 * @private
 */
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
