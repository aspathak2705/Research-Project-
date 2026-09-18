class WifiNetwork {
  final String ssid;
  final String signalStrength;
  final bool isSecured;

  const WifiNetwork({
    required this.ssid,
    required this.signalStrength,
    required this.isSecured,
  });
}
