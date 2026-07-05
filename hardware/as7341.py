from __future__ import annotations

import logging
import random
from dataclasses import dataclass

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class AS7341Sample:
    channels: dict[str, int]
    saturated: bool


class AS7341Sensor:
    CHANNEL_NAMES = ("f1_415nm", "f2_445nm", "f3_480nm", "f4_515nm", "f5_555nm", "nir")

    def __init__(self, mock_mode: bool = True) -> None:
        self.mock_mode = mock_mode

    def configure(self) -> None:
        LOGGER.info("AS7341 configured. mock_mode=%s", self.mock_mode)

    def read_sample(self) -> AS7341Sample:
        channels = {
            name: random.randint(8_000, 20_000) for name in self.CHANNEL_NAMES
        }
        return AS7341Sample(channels=channels, saturated=False)

