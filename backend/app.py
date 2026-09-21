from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.api import health, network, device, patients, sessions, diagnostics

app = FastAPI(
    title="HemoPi Backend API",
    description="Raspberry Pi Portable Non-Invasive Hemoglobin Analyzer Backend",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(network.router)
app.include_router(device.router)
app.include_router(patients.router)
app.include_router(sessions.router)
app.include_router(diagnostics.router)

@app.get("/")
def root():
    return {
        "service": "HemoPi API",
        "status": "OPERATIONAL",
        "docs": "/docs"
    }
