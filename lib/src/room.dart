/**
 * @file Compnume room model with early and late reflections.
 * @author Andrew Allen <bitllama@google.com>
 */

// Internal dependencies.
import 'dart:math';
import 'dart:web_audio';

import 'late_reflections.dart';
import 'early_reflections.dart';
import 'reso_utils.dart';

/**
 * Generate absorption coefficients from material names.
 * @param {Object} materials
 * @return {Object}
 */
Map<String, dynamic> _getCoefficientsFromMaterials(
    Map<String, dynamic> materials) {
  // Initialize coefficients to use defaults.
  Map<String, dynamic> coefficients = Map<String, num>();

  ResoUtils.DEFAULT_ROOM_MATERIALS.forEach((property, value) {
    if (ResoUtils.DEFAULT_ROOM_MATERIALS.containsKey(property)) {
      coefficients[property] = ResoUtils.ROOM_MATERIAL_COEFFICIENTS[
          ResoUtils.DEFAULT_ROOM_MATERIALS[property]];
    }
  });

  // Sanitize materials.
  if (materials == null) {
    materials = ResoUtils.DEFAULT_ROOM_MATERIALS;
  }

  // Assign coefficients using provided materials.
  ResoUtils.DEFAULT_ROOM_MATERIALS.forEach((property, value) {
    if (ResoUtils.DEFAULT_ROOM_MATERIALS.containsKey(property) &&
        materials.containsKey(property)) {
      if (ResoUtils.ROOM_MATERIAL_COEFFICIENTS
          .containsValue(materials[property])) {
        coefficients[property] =
            ResoUtils.ROOM_MATERIAL_COEFFICIENTS[materials[property]];
      } else {
        print('Material \"' +
            materials[property] +
            '\" on wall \"' +
            property +
            '\" not found. Using \"' +
            ResoUtils.DEFAULT_ROOM_MATERIALS[property] +
            '\".');
      }
    } else {
      print('Wall \"' + property + '\" is not defined. Default used.');
    }
  });
  return coefficients;
}

/**
 * Sanitize coefficients.
 * @param {Object} coefficients
 * @return {Object}
 */
Map<String, dynamic> _sanitizeCoefficients(Map<String, dynamic> coefficients) {
  if (coefficients == null) {
    coefficients = new Map<String, dynamic>();
  }

  ResoUtils.DEFAULT_ROOM_MATERIALS.forEach((property, value) {
    if (!(coefficients.containsKey(property))) {
      // If element is not present, use default coefficients.
      coefficients[property] = ResoUtils.ROOM_MATERIAL_COEFFICIENTS[
          ResoUtils.DEFAULT_ROOM_MATERIALS[property]];
    }
  });
  return coefficients;
}

/**
 * Sanitize dimensions.
 * @param {ResoUtils~RoomDimensions} dimensions
 * @return {ResoUtils~RoomDimensions}
 */
Map<String, dynamic> _sanitizeDimensions(Map<String, dynamic> dimensions) {
  if (dimensions == null) {
    dimensions = {};
  }
  ResoUtils.DEFAULT_ROOM_DIMENSIONS.forEach((property, value) {
    if (!(dimensions.containsKey(property))) {
      dimensions[property] = ResoUtils.DEFAULT_ROOM_DIMENSIONS[property];
    }
  });

  return dimensions;
}

/**
 * Compute frequency-dependent reverb durations.
 * @param {ResoUtils~RoomDimensions} dimensions
 * @param {Object} coefficients
 * @param {Number} speedOfSound
 * @return {Array}
 */
List<num> _getDurationsFromProperties(Map<String, dynamic> dimensions,
    Map<String, dynamic> coefficients, num speedOfSound) {
  List<num> durations = new List<num>(ResoUtils.NUMBER_REVERB_FREQUENCY_BANDS);

  // Sanitize inputs.
  dimensions = _sanitizeDimensions(dimensions);
  coefficients = _sanitizeCoefficients(coefficients);
  if (speedOfSound == null) {
    speedOfSound = ResoUtils.DEFAULT_SPEED_OF_SOUND;
  }

  // Acoustic constant.
  num k = ResoUtils.TWENTY_FOUR_LOG10 / speedOfSound;

  // Compute volume, skip if room is not present.
  num volume = dimensions['width'] * dimensions['height'] * dimensions['depth'];
  if (volume < ResoUtils.ROOM_MIN_VOLUME) {
    return durations;
  }

  // Room surface area.
  num leftRightArea = dimensions['width'] * dimensions['height'];
  num floorCeilingArea = dimensions['width'] * dimensions['depth'];
  num frontBackArea = dimensions['depth'] * dimensions['height'];
  num totalArea = 2 * (leftRightArea + floorCeilingArea + frontBackArea);
  for (num i = 0; i < ResoUtils.NUMBER_REVERB_FREQUENCY_BANDS; i++) {
    // Effective absorptive area.
    num absorbtionArea = (coefficients['left'][i] + coefficients['right'][i]) *
            leftRightArea +
        (coefficients['down'][i] + coefficients['up'][i]) * floorCeilingArea +
        (coefficients['front'][i] + coefficients['back'][i]) * frontBackArea;
    num meanAbsorbtionArea = absorbtionArea / totalArea;

    // Compute reverberation using Eyring equation [1].
    // [1] Beranek, Leo L. "Analysis of Sabine and Eyring equations and their
    //     application to concert hall audience and chair absorption." The
    //     Journal of the Acoustical Society of America, Vol. 120, No. 3.
    //     (2006), pp. 1399-1399.
    durations[i] = ResoUtils.ROOM_EYRING_CORRECTION_COEFFICIENT *
        k *
        volume /
        (-totalArea * log(1 - meanAbsorbtionArea) +
            4 * ResoUtils.ROOM_AIR_ABSORPTION_COEFFICIENTS[i] * volume);
  }
  return durations;
}

/**
 * Compute reflection coefficients from absorption coefficients.
 * @param {Object} absorptionCoefficients
 * @return {Object}
 */
Map<String, dynamic> _computeReflectionCoefficients(
    Map<String, dynamic> absorptionCoefficients) {
  Map<String, dynamic> reflectionCoefficients = Map<String, dynamic>();
  ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.forEach((property, value) {
    if (ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.containsKey(property)) {
      // Compute average absorption coefficient (per wall).
      reflectionCoefficients[property] = 0;
      for (num j = 0; j < ResoUtils.NUMBER_REFLECTION_AVERAGING_BANDS; j++) {
        num bandIndex = j + ResoUtils.ROOM_STARTING_AVERAGING_BAND;
        reflectionCoefficients[property] +=
            absorptionCoefficients[property][bandIndex];
      }
      reflectionCoefficients[property] /=
          ResoUtils.NUMBER_REFLECTION_AVERAGING_BANDS;

      // Convert absorption coefficient to reflection coefficient.
      reflectionCoefficients[property] =
          sqrt(1 - reflectionCoefficients[property]);
    }
  });
  return reflectionCoefficients;
}

/**
 * @class Room
 * @description Model that manages early and late reflections using acoustic
 * properties and listener position relative to a rectangular room.
 * @param {AudioContext} context
 * Associated {@link
https://developer.mozilla.org/en-US/docs/Web/API/AudioContext AudioContext}.
 * @param {Object} options
 * @param {Float32Array} options.listenerPosition
 * The listener's initial position (in meters), where origin is the center of
 * the room. Defaults to {@linkcode ResoUtils.DEFAULT_POSITION DEFAULT_POSITION}.
 * @param {ResoUtils~RoomDimensions} options.dimensions Room dimensions (in meters). Defaults to
 * {@linkcode ResoUtils.DEFAULT_ROOM_DIMENSIONS DEFAULT_ROOM_DIMENSIONS}.
 * @param {ResoUtils~RoomMaterials} options.materials Named acoustic materials per wall.
 * Defaults to {@linkcode ResoUtils.DEFAULT_ROOM_MATERIALS DEFAULT_ROOM_MATERIALS}.
 * @param {Number} options.speedOfSound
 * (in meters/second). Defaults to
 * {@linkcode ResoUtils.DEFAULT_SPEED_OF_SOUND DEFAULT_SPEED_OF_SOUND}.
 */
class Room {
  // Public variables.
  /**
   * EarlyReflections {@link EarlyReflections EarlyReflections} submodule.
   * @member {AudioNode} early
   * @memberof Room
   * @instance
   */
  /**
   * LateReflections {@link LateReflections LateReflections} submodule.
   * @member {AudioNode} late
   * @memberof Room
   * @instance
   */
  /**
   * Ambisonic (multichannel) output {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} output
   * @memberof Room
   * @instance
   */

  EarlyReflections earlyReflections;
  LateReflections lateReflections;
  num speedOfSound;
  ChannelMergerNode _merger;
  GainNode output;

  Room(AudioContext context, Map<String, dynamic> options) {
    // Use defaults for null arguments.
    if (options == null) {
      options = {};
    }
    if (options['listenerPosition'] == null) {
      options['listenerPosition'] = ResoUtils.DEFAULT_POSITION;
    }
    if (options['dimensions'] == null) {
      options['dimensions'] = ResoUtils.DEFAULT_ROOM_DIMENSIONS;
    }
    if (options['materials'] == null) {
      options['materials'] = ResoUtils.DEFAULT_ROOM_MATERIALS;
    }
    if (options['speedOfSound'] == null) {
      options['speedOfSound'] = ResoUtils.DEFAULT_SPEED_OF_SOUND;
    }

    // Sanitize room-properties-related arguments.
    options['dimensions'] = _sanitizeDimensions(options['dimensions']);
    Map<String, dynamic> absorptionCoefficients =
        _getCoefficientsFromMaterials(options['materials']);
    Map<String, dynamic> reflectionCoefficients =
        _computeReflectionCoefficients(absorptionCoefficients);
    List<num> durations = _getDurationsFromProperties(
        options['dimensions'], absorptionCoefficients, options['speedOfSound']);

    // Construct submodules for early and late reflections.
    earlyReflections = new EarlyReflections(context, {
      'dimensions': options['dimensions'],
      'coefficients': reflectionCoefficients,
      'speedOfSound': options['speedOfSound'],
      'listenerPosition': options['listenerPosition'],
    });
    lateReflections = new LateReflections(context, {
      'durations': durations,
    });

    speedOfSound = options['speedOfSound'];

    // Construct auxillary audio nodes.
    output = context.createGain();
    earlyReflections.output.connectNode(output);
    _merger = context.createChannelMerger(4);

    lateReflections.output.connectNode(_merger, 0, 0);
    _merger.connectNode(output);
  }

/**
 * Set the room's dimensions and wall materials.
 * @param {ResoUtils~RoomDimensions} dimensions Room dimensions (in meters). Defaults to
 * {@linkcode ResoUtils.DEFAULT_ROOM_DIMENSIONS DEFAULT_ROOM_DIMENSIONS}.
 * @param {ResoUtils~RoomMaterials} materials Named acoustic materials per wall. Defaults to
 * {@linkcode ResoUtils.DEFAULT_ROOM_MATERIALS DEFAULT_ROOM_MATERIALS}.
 */
  void setProperties(
      Map<String, dynamic> dimensions, Map<String, dynamic> materials) {
    // Compute late response.
    Map<String, dynamic> absorptionCoefficients =
        _getCoefficientsFromMaterials(materials);
    List<num> durations = _getDurationsFromProperties(
        dimensions, absorptionCoefficients, speedOfSound);
    lateReflections.setDurations(durations);

    // Compute early response.
    earlyReflections.speedOfSound = speedOfSound;
    Map<String, dynamic> reflectionCoefficients =
        _computeReflectionCoefficients(absorptionCoefficients);
    earlyReflections.setRoomProperties(dimensions, reflectionCoefficients);
  }

/**
 * Set the listener's position (in meters), where origin is the center of
 * the room.
 * @param {Number} x
 * @param {Number} y
 * @param {Number} z
 */
  void setListenerPosition(num x, num y, num z) {
    earlyReflections.speedOfSound = speedOfSound;
    earlyReflections.setListenerPosition(x, y, z);

    // Disable room effects if the listener is outside the room boundaries.
    num distance = getDistanceOutsideRoom(x, y, z);
    num gain = 1;
    if (distance > ResoUtils.EPSILON_FLOAT) {
      gain = 1 - distance / ResoUtils.LISTENER_MAX_OUTSIDE_ROOM_DISTANCE;

      // Clamp gain between 0 and 1.
      gain = max(0, min(1, gain));
    }
    output.gain.value = gain;
  }

/**
 * Compute distance outside room of provided position (in meters).
 * @param {Number} x
 * @param {Number} y
 * @param {Number} z
 * @return {Number}
 * Distance outside room (in meters). Returns 0 if inside room.
 */
  num getDistanceOutsideRoom(num x, num y, num z) {
    num dx = max(
        0,
        max(-earlyReflections.halfDimensions['width'] - x,
            x - earlyReflections.halfDimensions['width']));
    num dy = max(
        0,
        max(-earlyReflections.halfDimensions['height'] - y,
            y - earlyReflections.halfDimensions['height']));
    num dz = max(
        0,
        max(-earlyReflections.halfDimensions['depth'] - z,
            z - earlyReflections.halfDimensions['depth']));
    return sqrt(dx * dx + dy * dy + dz * dz);
  }
}
