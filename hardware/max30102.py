from __future__ import annotations

import logging
from dataclasses import dataclass
from math import sin

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class Max30102Sample:
    red: int
    ir: int
    finger_detected: bool


class MAX30102Sensor:
    def __init__(self, mock_mode: bool = True) -> None:
        self.mock_mode = mock_mode
        self._sample_index = 0

    def configure(self) -> None:
        LOGGER.info("MAX30102 configured. mock_mode=%s", self.mock_mode)

    def finger_detected(self) -> bool:
        return True

    def read_sample(self) -> Max30102Sample:
        self._sample_index += 1
        pulse = int(sin(self._sample_index / 2.5) * 220)
        drift = (self._sample_index % 5) * 15
        base_ir = 50_000 + drift
        base_red = 46_000 + drift
        return Max30102Sample(
            red=base_red + pulse,
            ir=base_ir - pulse,
            finger_detected=True,
        )
