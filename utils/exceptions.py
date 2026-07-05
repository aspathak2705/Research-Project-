class HemoAnalyzerError(Exception):
    """Base exception for analyzer errors."""


class HardwareError(HemoAnalyzerError):
    """Raised when sensor or bus communication fails."""


class SignalQualityError(HemoAnalyzerError):
    """Raised when captured data fails quality checks."""


class StorageError(HemoAnalyzerError):
    """Raised when local persistence fails."""


class CloudSyncError(HemoAnalyzerError):
    """Raised when cloud sync fails."""

