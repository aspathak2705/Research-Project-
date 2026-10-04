# HemoPi AS7341 Physical Production Validation Protocol

## 1. Overview
This validation protocol characterizies the physical AS7341 8-channel multispectral optical sensor across dark baseline, reference illumination, and controlled optical response using the unmodified HemoPi production acquisition driver (`adafruit-circuitpython-as7341==1.2.27` on I2C Bus 1 @ address `0x39`).

> [!IMPORTANT]
> - This protocol requires physical hardware (Raspberry Pi 4 with AS7341 connected).
> - Synthetic biomedical data and manufactured readings are strictly prohibited.
> - The research acquisition gate remains active (`HTTP 409`) until formal review of physical evidence.

---

## 2. Hardware & Software Prerequisites
- **Instrument**: Raspberry Pi 4 Model B
- **Sensor**: ams AS7341 Multispectral Sensor on I2C Bus 1 (`0x39`)
- **Driver**: `adafruit-circuitpython-as7341==1.2.27`
- **Python**: $\ge$ 3.9

---

## 3. Physical Test Execution Sequence

### Phase 0: Physical Hardware Preflight Check
Before data collection, verify the physical environment and device ACK:
```bash
python -m validation.as7341.device_check
```
*If physical sensor ACK is not received at `0x39`, stop immediately and inspect wiring.*

---

### Phase 1: Dark Baseline Acquisition
1. Cover the sensor optical aperture completely with an opaque light-tight enclosure.
2. Acquire 30 repeated physical readings:
```bash
python -m validation.as7341.cli capture --condition DARK --samples 30
```
Note the generated run directory printed in output (e.g. `validation/outputs/20261004_120000_RUN_20261004_120000`).

---

### Phase 2: Reference Light Illumination
1. Expose the sensor to a stable, calibrated optical reference source at fixed geometry.
2. Record reference readings into the existing run directory:
```bash
python -m validation.as7341.cli capture --condition REFERENCE_LIGHT --samples 30 --run-dir validation/outputs/<RUN_DIRECTORY>
```

---

### Phase 3: Controlled Optical Response (Optional / Extended)
If testing secondary optical conditions:
```bash
python -m validation.as7341.cli capture --condition CONTROLLED_RESPONSE --samples 30 --run-dir validation/outputs/<RUN_DIRECTORY>
```

---

### Phase 4: Evidence Package & Report Generation
Run the automated statistical analyzer and evidence generator on the captured physical run:
```bash
python -m validation.as7341.cli analyze --run-dir validation/outputs/<RUN_DIRECTORY>
```

---

## 4. Evidence Package Artifacts
Upon completion, the validation directory contains:
- `manifest.json`: Machine-readable hardware and software provenance.
- `raw/*.csv`: Raw, unmodified ADC counts per channel.
- `analysis/channel_statistics.csv`: Mean, SD, min, max, range, CV%, and stuck-channel flags.
- `analysis/optical_response.csv`: Delta response between baseline and illumination.
- `plots/*.svg`: Publication-ready spectral response and temporal stability charts.
- `report/AS7341_Physical_Validation_Report.md`: Full human-readable audit report.
- `SHA256SUMS.txt`: Cryptographic checksums of all evidence files.
