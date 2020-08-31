import 'dart:web_audio';

/**
 * @file ResonanceAudio library name space and common utilities.
 * @author Andrew Allen <bitllama@google.com>
 */

// Internal dependencies.
import 'listener.dart';
import 'source.dart';
import 'room.dart';
import 'encoder.dart';
import 'reso_utils.dart';

/**
 * Options for constructing a new ResonanceAudio scene.
 * @typedef {Object} ResonanceAudio~ResonanceAudioOptions
 * @property {Number} ambisonicOrder
 * Desired ambisonic Order. Defaults to
 * {@linkcode ResoUtils.DEFAULT_AMBISONIC_ORDER DEFAULT_AMBISONIC_ORDER}.
 * @property {Float32Array} listenerPosition
 * The listener's initial position (in meters), where origin is the center of
 * the room. Defaults to {@linkcode ResoUtils.DEFAULT_POSITION DEFAULT_POSITION}.
 * @property {Float32Array} listenerForward
 * The listener's initial forward vector.
 * Defaults to {@linkcode ResoUtils.DEFAULT_FORWARD DEFAULT_FORWARD}.
 * @property {Float32Array} listenerUp
 * The listener's initial up vector.
 * Defaults to {@linkcode ResoUtils.DEFAULT_UP DEFAULT_UP}.
 * @property {ResoUtils~RoomDimensions} dimensions Room dimensions (in meters). Defaults to
 * {@linkcode ResoUtils.DEFAULT_ROOM_DIMENSIONS DEFAULT_ROOM_DIMENSIONS}.
 * @property {ResoUtils~RoomMaterials} materials Named acoustic materials per wall.
 * Defaults to {@linkcode ResoUtils.DEFAULT_ROOM_MATERIALS DEFAULT_ROOM_MATERIALS}.
 * @property {Number} speedOfSound
 * (in meters/second). Defaults to
 * {@linkcode ResoUtils.DEFAULT_SPEED_OF_SOUND DEFAULT_SPEED_OF_SOUND}.
 */

/**
 * @class ResonanceAudio
 * @description Main class for managing sources, room and listener models.
 * @param {AudioContext} context
 * Associated {@link
https://developer.mozilla.org/en-US/docs/Web/API/AudioContext AudioContext}.
 * @param {ResonanceAudio~ResonanceAudioOptions} options
 * Options for constructing a new ResonanceAudio scene.
 */
class ResonanceAudio {
  // Public variables.
  /**
   * Binaurally-rendered stereo (2-channel) output {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} output
   * @memberof ResonanceAudio
   * @instance
   */
  /**
   * Ambisonic (multichannel) input {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}
   * (For rendering input soundfields).
   * @member {AudioNode} ambisonicInput
   * @memberof ResonanceAudio
   * @instance
   */
  /**
   * Ambisonic (multichannel) output {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}
   * (For allowing external rendering / post-processing).
   * @member {AudioNode} ambisonicOutput
   * @memberof ResonanceAudio
   * @instance
   */

  num ambisonicOrder;
  List<Source> _sources;
  Room room;
  Listener listener;
  AudioContext context;
  GainNode output;
  GainNode ambisonicOutput;
  GainNode ambisonicInput;

  ResonanceAudio(AudioContext _context, Map<String, dynamic> options) {
    // Use defaults for null arguments.
    if (options == null) {
      options = {};
    }
    if (options['ambisonicOrder'] == null) {
      options['ambisonicOrder'] = ResoUtils.DEFAULT_AMBISONIC_ORDER;
    }
    if (options['listenerPosition'] == null) {
      options['listenerPosition'] = ResoUtils.DEFAULT_POSITION;
    }
    if (options['listenerForward'] == null) {
      options['listenerForward'] = ResoUtils.DEFAULT_FORWARD;
    }
    if (options['listenerUp'] == null) {
      options['listenerUp'] = ResoUtils.DEFAULT_UP;
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

    // Create member submodules.
    ambisonicOrder = Encoder.validateAmbisonicOrder(options['ambisonicOrder']);
    _sources = new List<Source>();
    room = new Room(context, {
      'listenerPosition': options['listenerPosition'],
      'dimensions': options['dimensions'],
      'materials': options['materials'],
      'speedOfSound': options['speedOfSound'],
    });
    listener = new Listener(context, {
      'ambisonicOrder': options['ambisonicOrder'],
      'position': options['listenerPosition'],
      'forward': options['listenerForward'],
      'up': options['listenerUp'],
    });

    // Create auxillary audio nodes.
    context = _context;
    output = context.createGain();
    ambisonicOutput = context.createGain();
    ambisonicInput = listener.input;

    // Connect audio graph.
    room.output.connectNode(listener.input);
    listener.output.connectNode(output);
    listener.ambisonicOutput.connectNode(ambisonicOutput);
  }

/**
 * Create a new source for the scene.
 * @param {Source~SourceOptions} options
 * Options for constructing a new Source.
 * @return {Source}
 */
  Source createSource(Map<String, dynamic> options) {
    // Create a source and push it to the internal sources array, returning
    // the object's reference to the user.
    Source source = new Source(this, options);
    _sources[_sources.length] = source;
    return source;
  }

/**
 * Set the scene's desired ambisonic order.
 * @param {Number} ambisonicOrder Desired ambisonic order.
 */
  void setAmbisonicOrder(num ambisonicOrder) {
    ambisonicOrder = Encoder.validateAmbisonicOrder(ambisonicOrder);
  }

/**
 * Set the room's dimensions and wall materials.
 * @param {Object} dimensions Room dimensions (in meters).
 * @param {Object} materials Named acoustic materials per wall.
 */
  void setRoomProperties(
      Map<String, dynamic> dimensions, Map<String, dynamic> materials) {
    room.setProperties(dimensions, materials);
  }

/**
 * Set the listener's position (in meters), where origin is the center of
 * the room.
 * @param {Number} x
 * @param {Number} y
 * @param {Number} z
 */
  void setListenerPosition(num x, num y, num z) {
    // Update listener position.
    listener.position[0] = x;
    listener.position[1] = y;
    listener.position[2] = z;
    room.setListenerPosition(x, y, z);

    // Update sources with new listener position.
    _sources.forEach((element) {
      element.update();
    });
  }

/**
 * Set the source's orientation using forward and up vectors.
 * @param {Number} forwardX
 * @param {Number} forwardY
 * @param {Number} forwardZ
 * @param {Number} upX
 * @param {Number} upY
 * @param {Number} upZ
 */
  void setListenerOrientation(
      num forwardX, num forwardY, num forwardZ, num upX, num upY, num upZ) {
    listener.setOrientation(forwardX, forwardY, forwardZ, upX, upY, upZ);
  }

/**
 * Set the speed of sound.
 * @param {Number} speedOfSound
 */
  void setSpeedOfSound(num speedOfSound) {
    room.speedOfSound = speedOfSound;
  }
}
