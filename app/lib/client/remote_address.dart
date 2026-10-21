import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

/// Where to reach a paired Mac that Bonjour can't see, such as over Tailscale: a name (`studio-mac`,
/// `studio-mac.tail1234.ts.net`) or an address (`100.101.102.103`, `fd7a:115c:a1e0::1`), and a port that
/// is the Mac's usual one unless given (`studio-mac:47900`, `[fd7a:115c:a1e0::1]:47900`).
@immutable
final class RemoteAddress {
  const RemoteAddress(this.host, [this.port = portholeSignalingPort]);

  /// A DNS name, or an IPv4 or IPv6 address without brackets.
  final String host;
  final int port;

  bool get isIp => InternetAddress.tryParse(host) != null;
  bool get _isIPv6 => InternetAddress.tryParse(host)?.type == InternetAddressType.IPv6;

  /// How to show and store it, the port left out when it's the usual one.
  String get text => switch ((port == portholeSignalingPort, _isIPv6)) {
        (true, _) => host,
        (false, true) => '[$host]:$port',
        (false, false) => '$host:$port',
      };

  /// What the person typed, or null if it can't be a name or address with an optional port.
  static RemoteAddress? parse(String typed) {
    final text = typed.trim().toLowerCase();
    if (text.isEmpty || text.length > 270) return null;
    final String host;
    final String? port;
    if (text.startsWith('[')) {
      final close = text.indexOf(']');
      if (close < 0) return null;
      host = text.substring(1, close);
      final rest = text.substring(close + 1);
      if (rest.isNotEmpty && !rest.startsWith(':')) return null;
      port = rest.isEmpty ? null : rest.substring(1);
      if (!_isIPv6Text(host)) return null;
    } else if (':'.allMatches(text).length > 1) {
      // A bare IPv6 address: with no brackets, there's no room for a port.
      host = text;
      port = null;
      if (!_isIPv6Text(host)) return null;
    } else {
      final colon = text.indexOf(':');
      host = colon < 0 ? text : text.substring(0, colon);
      port = colon < 0 ? null : text.substring(colon + 1);
      if (!_isNameOrIPv4(host)) return null;
    }
    if (port == null) return RemoteAddress(host);
    final number = int.tryParse(port);
    if (number == null || '$number' != port || number < 1 || number > 65535) return null;
    return RemoteAddress(host, number);
  }

  static bool _isIPv6Text(String text) =>
      !text.contains('%') && InternetAddress.tryParse(text)?.type == InternetAddressType.IPv6;

  static final _label = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');

  /// A DNS name of letters, digits and hyphens, or a dotted IPv4 address. All-digit names are read as
  /// addresses, so a mistyped one like 100.101.102.300 is refused rather than looked up.
  static bool _isNameOrIPv4(String text) {
    final name = text.endsWith('.') ? text.substring(0, text.length - 1) : text;
    if (name.isEmpty || name.length > 253) return false;
    final labels = name.split('.');
    if (labels.every((label) => RegExp(r'^\d+$').hasMatch(label))) {
      return labels.length == 4 && InternetAddress.tryParse(name)?.type == InternetAddressType.IPv4;
    }
    return labels.every(_label.hasMatch);
  }

  @override
  bool operator ==(Object other) => other is RemoteAddress && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => 'RemoteAddress($text)';
}
