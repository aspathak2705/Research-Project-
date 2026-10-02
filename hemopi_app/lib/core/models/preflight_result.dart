class PreflightResult {
  final bool isReachable;
  final bool isSoftwareHealthy;
  final bool isI2cAvailable;
  final bool isAs7341Detected;
  final bool isAs7341Initialized;
  final bool isMax30102Detected;
  final bool isMax30102Initialized;
  final bool isResearchValidated;
  final bool isAcquisitionReady;
  final String statusMessage;
  final String? detailedReason;

  const PreflightResult({
    required this.isReachable,
    required this.isSoftwareHealthy,
    required this.isI2cAvailable,
    required this.isAs7341Detected,
    required this.isAs7341Initialized,
    required this.isMax30102Detected,
    required this.isMax30102Initialized,
    required this.isResearchValidated,
    required this.isAcquisitionReady,
    required this.statusMessage,
    this.detailedReason,
  });

  factory PreflightResult.offline() {
    return const PreflightResult(
      isReachable: false,
      isSoftwareHealthy: false,
      isI2cAvailable: false,
      isAs7341Detected: false,
      isAs7341Initialized: false,
      isMax30102Detected: false,
      isMax30102Initialized: false,
      isResearchValidated: false,
      isAcquisitionReady: false,
      statusMessage: 'HemoPi instrument is not reachable. Ensure it is powered on and joined to the clinic network.',
      detailedReason: 'DEVICE_UNREACHABLE',
    );
  }
}
