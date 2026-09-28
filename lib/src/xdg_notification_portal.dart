import 'dart:io';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';

/// Priorities for notifications.
enum XdgNotificationPriority { low, normal, high, urgent }

/// Ways a notification can be displayed (`display-hint`, since portal v2).
enum XdgNotificationDisplayHint {
  /// Only shown as a banner, not kept in the tray. Can't be combined with [tray].
  transient('transient'),

  /// Not shown as a banner, only placed in the tray. Can't be combined with [transient].
  tray('tray'),

  /// Can't be dismissed by the user; removed once the app's last window closes.
  persistent('persistent'),

  /// Don't show the notification on the lock screen.
  hideOnLockScreen('hide-on-lock-screen'),

  /// Hide all content of the notification on the lock screen.
  hideContentOnLockScreen('hide-content-on-lock-screen'),

  /// Remove the old notification with the same id and add a new one,
  /// instead of updating it in place.
  showAsNew('show-as-new');

  const XdgNotificationDisplayHint(this.value);

  /// Value sent over D-Bus.
  final String value;
}

/// Standardized notification categories (since portal v2).
/// Servers may also define `x-vendor` categories, so [XdgNotification.category]
/// is a plain string; these are the standard values.
abstract final class XdgNotificationCategory {
  static const imReceived = 'im.received';
  static const alarmRinging = 'alarm.ringing';
  static const callIncoming = 'call.incoming';
  static const callOngoing = 'call.ongoing';
  static const callUnanswered = 'call.unanswered';
  static const weatherWarningExtreme = 'weather.warning.extreme';
  static const cellbroadcastDangerPresidential =
      'cellbroadcast.danger.presidential';
  static const cellbroadcastDangerExtreme = 'cellbroadcast.danger.extreme';
  static const cellbroadcastDangerSevere = 'cellbroadcast.danger.severe';
  static const cellbroadcastPublicSafety = 'cellbroadcast.public-safety';
  static const cellbroadcastAmberAlert = 'cellbroadcast.amber-alert';
  static const cellbroadcastTest = 'cellbroadcast.test';
  static const osBatteryLow = 'os.battery.low';
  static const browserWebNotification = 'browser.web-notification';
}

/// Standardized button purposes (since portal v2).
abstract final class XdgNotificationButtonPurpose {
  static const systemCustomAlert = 'system.custom-alert';
  static const imReplyWithText = 'im.reply-with-text';
  static const callAccept = 'call.accept';
  static const callDecline = 'call.decline';
  static const callHangUp = 'call.hang-up';
  static const callEnableSpeakerphone = 'call.enable-speakerphone';
  static const callDisableSpeakerphone = 'call.disable-speakerphone';
}

/// An icon to be shown in a notification.
abstract class XdgNotificationIcon {}

/// A themed icon.
class XdgNotificationIconThemed extends XdgNotificationIcon {
  /// Theme names to lookup for this icon in order of priority.
  final List<String> names;

  XdgNotificationIconThemed(this.names);
}

/// An icon backed by a file descriptor to a png, jpeg or svg image (since v2).
///
/// The descriptor must be sealable, which currently means it has to come from
/// `memfd_create()` with `MFD_ALLOW_SEALING`.
class XdgNotificationIconFileDescriptor extends XdgNotificationIcon {
  /// Handle of the image file.
  final ResourceHandle handle;

  XdgNotificationIconFileDescriptor(this.handle);
}

/// An icon with image data.
@Deprecated('Deprecated since portal version 2. '
    'Use XdgNotificationIconThemed or XdgNotificationIconFileDescriptor.')
class XdgNotificationIconData extends XdgNotificationIcon {
  /// Image data for this icon.
  final Uint8List data;

  XdgNotificationIconData(this.data);
}

/// A sound to play with a notification (since portal v2).
abstract class XdgNotificationSound {
  const XdgNotificationSound();
}

/// Play the default notification sound.
class XdgNotificationSoundDefault extends XdgNotificationSound {
  const XdgNotificationSoundDefault();
}

/// Play no sound at all.
class XdgNotificationSoundSilent extends XdgNotificationSound {
  const XdgNotificationSoundSilent();
}

/// Play a sound from a file descriptor (ogg/opus, ogg/vorbis or wav/pcm).
///
/// The descriptor must be sealable, see [XdgNotificationIconFileDescriptor].
class XdgNotificationSoundFileDescriptor extends XdgNotificationSound {
  /// Handle of the sound file.
  final ResourceHandle handle;

  const XdgNotificationSoundFileDescriptor(this.handle);
}

/// A button to be shown in a notification.
class XdgNotificationButton {
  /// Label on this button.
  /// Mandatory if no [purpose] is given; strongly recommended in any case.
  final String? label;

  /// Name of the exported action to perform with this button.
  final String action;

  /// Target parameter sent along when activating the action.
  final String? target;

  /// Purpose of this button, see [XdgNotificationButtonPurpose] (since v2).
  /// Servers that don't understand a purpose show a normal button.
  final String? purpose;

  XdgNotificationButton({
    this.label,
    required this.action,
    this.target,
    this.purpose,
  }) : assert(label != null || purpose != null,
            'A button needs a label or a purpose');
}

/// An event that is emitted when a notification action is invoked.
class XdgNotificationActionInvokedEvent {
  /// Id of the notification that this action was invoked on.
  final String id;

  /// Name of the action that was invoked.
  final String action;

  /// Target passed for the action, if one was specified as a string.
  final String? target;

  /// Activation token for XDG Activation (since v2).
  final String? activationToken;

  /// Text entered by the user for purposes like `im.reply-with-text` (since v2).
  final String? response;

  const XdgNotificationActionInvokedEvent(
    this.id,
    this.action, {
    this.target,
    this.activationToken,
    this.response,
  });

  @override
  int get hashCode =>
      Object.hash(id, action, target, activationToken, response);

  @override
  bool operator ==(other) =>
      other is XdgNotificationActionInvokedEvent &&
      other.id == id &&
      other.action == action &&
      other.target == target &&
      other.activationToken == activationToken &&
      other.response == response;

  @override
  String toString() =>
      '$runtimeType($id, $action, target: $target, '
      'activationToken: $activationToken, response: $response)';
}

/// Options advertised by the notification server (since portal v2).
class XdgNotificationSupportedOptions {
  /// Categories the server understands, see [XdgNotificationCategory].
  final Set<String> categories;

  /// Button purposes the server understands, see [XdgNotificationButtonPurpose].
  final Set<String> buttonPurposes;

  const XdgNotificationSupportedOptions({
    this.categories = const {},
    this.buttonPurposes = const {},
  });
}

/// Portal to create notifications.
class XdgNotificationPortal {
  static const _interface = 'org.freedesktop.portal.Notification';

  final DBusRemoteObject _object;

  XdgNotificationPortal(this._object);

  /// Get the version of this portal.
  Future<int> getVersion() => _object
      .getProperty(_interface, 'version', signature: DBusSignature('u'))
      .then((v) => v.asUint32());

  /// Get the options advertised by the notification server (since v2).
  Future<XdgNotificationSupportedOptions> getSupportedOptions() => _object
      .getProperty(
        _interface,
        'SupportedOptions',
        signature: DBusSignature('a{sv}'),
      )
      .then((v) {
        final options = v.asStringVariantDict();
        return XdgNotificationSupportedOptions(
          categories:
              options['category']?.asStringArray().toSet() ?? const {},
          buttonPurposes:
              options['button-purpose']?.asStringArray().toSet() ?? const {},
        );
      });

  /// Send a notification.
  /// [id] can be used later to withdraw the notification with [removeNotification].
  /// If [id] is reused without withdrawing, the existing notification is updated
  /// (or replaced with an animation if [displayHints] contains
  /// [XdgNotificationDisplayHint.showAsNew]).
  ///
  /// [markupBody] is like [body] but supports `<b>`, `<i>` and `<a href>`
  /// markup (since v2).
  Future<void> addNotification(
    String id, {
    String? title,
    String? body,
    String? markupBody,
    XdgNotificationIcon? icon,
    XdgNotificationSound? sound,
    XdgNotificationPriority? priority,
    String? defaultAction,
    String? defaultActionTarget,
    List<XdgNotificationButton> buttons = const [],
    List<XdgNotificationDisplayHint> displayHints = const [],
    String? category,
  }) async {
    final notification = <String, DBusValue>{};

    if (title != null) {
      notification['title'] = DBusString(title);
    }

    if (body != null) {
      notification['body'] = DBusString(body);
    }

    if (markupBody != null) {
      notification['markup-body'] = DBusString(markupBody);
    }

    if (icon != null) {
      notification['icon'] = switch (icon) {
        XdgNotificationIconThemed(:final names) => DBusStruct([
            DBusString('themed'),
            DBusVariant(DBusArray.string(names)),
          ]),
        XdgNotificationIconFileDescriptor(:final handle) => DBusStruct([
            DBusString('file-descriptor'),
            DBusVariant(DBusUnixFd(handle)),
          ]),
        // ignore: deprecated_member_use_from_same_package
        XdgNotificationIconData(:final data) => DBusStruct([
            DBusString('bytes'),
            DBusVariant(DBusArray.byte(data)),
          ]),
        _ => throw ArgumentError.value(icon, 'icon', 'Unsupported icon type'),
      };
    }

    if (sound != null) {
      notification['sound'] = switch (sound) {
        XdgNotificationSoundDefault() => DBusString('default'),
        XdgNotificationSoundSilent() => DBusString('silent'),
        XdgNotificationSoundFileDescriptor(:final handle) => DBusStruct([
            DBusString('file-descriptor'),
            DBusVariant(DBusUnixFd(handle)),
          ]),
        _ => throw ArgumentError.value(sound, 'sound', 'Unsupported sound type'),
      };
    }

    if (priority != null) {
      // Enum names match the values defined by the portal.
      notification['priority'] = DBusString(priority.name);
    }

    if (defaultAction != null) {
      notification['default-action'] = DBusString(defaultAction);
    }

    if (defaultActionTarget != null) {
      notification['default-action-target'] = DBusString(defaultActionTarget);
    }

    if (buttons.isNotEmpty) {
      notification['buttons'] = DBusArray(
        DBusSignature('a{sv}'),
        buttons.map((button) => DBusDict.stringVariant({
              if (button.label != null) 'label': DBusString(button.label!),
              'action': DBusString(button.action),
              if (button.target != null)
                'target': DBusString(button.target!),
              if (button.purpose != null) 'purpose': DBusString(button.purpose!),
            })),
      );
    }

    if (displayHints.isNotEmpty) {
      notification['display-hint'] =
          DBusArray.string(displayHints.map((h) => h.value));
    }

    if (category != null) {
      notification['category'] = DBusString(category);
    }

    await _object.callMethod(
      _interface,
      'AddNotification',
      [DBusString(id), DBusDict.stringVariant(notification)],
      replySignature: DBusSignature(''),
    );
  }

  /// Withdraw a notification created with [addNotification].
  Future<void> removeNotification(String id) async {
    await _object.callMethod(
      _interface,
      'RemoveNotification',
      [DBusString(id)],
      replySignature: DBusSignature(''),
    );
  }

  /// Stream of invoked actions (only for actions not prefixed with `app.`).
  Stream<XdgNotificationActionInvokedEvent> get actionInvoked =>
      DBusRemoteObjectSignalStream(
        object: _object,
        interface: _interface,
        name: 'ActionInvoked',
        signature: DBusSignature('ssav'),
      ).map((DBusSignal signal) {
        final id = signal.values[0].asString();
        final action = signal.values[1].asString();

        // `parameter` holds, in order: the target (if one was specified),
        // the platform-data vardict containing `activation-token` (since v2),
        // and the user response for the button purpose, if applicable (since v2).
        final parameter =
            signal.values[2].asArray().map((v) => v.asVariant()).toList();

        String? target;
        String? activationToken;
        String? response;

        if (parameter.isNotEmpty && parameter[0] is DBusString) {
          target = parameter[0].asString();
        }
        if (parameter.length > 1) {
          final platformData = parameter[1].asStringVariantDict();
          activationToken = platformData['activation-token']?.asString();
        }
        if (parameter.length > 2) {
          response = parameter[2].asString();
        }

        return XdgNotificationActionInvokedEvent(
          id,
          action,
          target: target,
          activationToken: activationToken,
          response: response,
        );
      });
}