/// Response of Google's OAuth 2.0 device authorization endpoint
/// (`POST https://oauth2.googleapis.com/device/code`).
///
/// The user opens [verificationUrl] on any device and enters
/// [userCode]; the app polls the token endpoint with [deviceCode]
/// every [interval] seconds until the user approves or [expiresIn]
/// seconds pass.
class DeviceCodeResponse {
  const DeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUrl;

  /// Seconds until the codes expire.
  final int expiresIn;

  /// Minimum seconds to wait between token polls.
  final int interval;

  factory DeviceCodeResponse.fromJson(Map<String, dynamic> json) {
    return DeviceCodeResponse(
      deviceCode: json['device_code'] as String? ?? '',
      userCode: json['user_code'] as String? ?? '',
      // Google returns `verification_url`; some flows use the
      // `verification_uri` spelling. Accept both.
      verificationUrl:
          (json['verification_url'] ??
                  json['verification_uri'] ??
                  'https://www.youtube.com/activate')
              as String,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 1800,
      interval: (json['interval'] as num?)?.toInt() ?? 5,
    );
  }
}
