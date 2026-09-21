import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DEFAULT_HOSTNAME = os.getenv("HEMOPI_HOSTNAME", "hemopi.local")
PORT = int(os.getenv("HEMOPI_PORT", 8000))

DATA_DIR = os.path.join(BASE_DIR, "data")
PATIENTS_FILE = os.path.join(DATA_DIR, "patients.json")
SESSIONS_FILE = os.path.join(DATA_DIR, "sessions.json")
DIAGNOSTICS_FILE = os.path.join(DATA_DIR, "diagnostics.json")

# Ensure required storage directories exist
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(os.path.join(DATA_DIR, "rejected"), exist_ok=True)
