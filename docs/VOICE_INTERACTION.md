# ECHO Phase 8: Multimodal Voice Interaction Architecture

## 🎙️ Overview

Phase 8 introduces push-to-talk microphone capture, provider-neutral Speech-to-Text (STT) and Text-to-Speech (TTS) interfaces, spatial APC audio responses, and a typed command console fallback.

```
Microphone Capture (AudioCaptureService - Push-To-Talk 'V')
       │
       ▼
Speech-to-Text Provider (Mock / OpenAI-Compatible / Local)
       │
       ▼ (Transcript)
CommandGrounder ──► Grounded ActionRequest or TaskRequest
       │
       ▼
ActionController / InteractionController / TaskController
       │
       ▼ (APC Response Template)
Text-to-Speech Provider (Mock / OpenAI-Compatible / Local)
       │
       ▼
APC Voice Playback & Subtitles Overlay
```

---

## 🔒 Privacy & Safety Directives

1. **Explicit Push-to-Talk**: The microphone is active **only** while holding physical key **V** (`push_to_talk`). The game never records continuously or listens in the background.
2. **Zero Permanent Audio Retention**: Captured audio buffers reside strictly in runtime RAM memory (`AudioBuffer`) and are freed immediately after transcription. No audio files are written to disk or committed to git.
3. **Provider Privacy Options**: Cloud speech services (OpenAI-compatible endpoints) require explicit configuration. Fully offline, private operation is supported via local providers (`LocalSTTProvider`, `LocalTTSProvider`).
4. **Safety Isolation**: Speech is an **input channel**, not an execution authority. Transcripts cannot directly modify physics, velocity, transforms, files, or shell commands.

---

## ⚙️ Configuration Variables

Configuration uses standard environment variables:

```bash
# Push-to-Talk Recording Bounds
ECHO_PTT_MIN_SECONDS=0.25
ECHO_PTT_MAX_SECONDS=20

# Speech-to-Text Configuration
ECHO_STT_ENABLED=true
ECHO_STT_PROVIDER=openai_compatible # mock | openai_compatible | local
ECHO_STT_BASE_URL=https://api.openai.com/v1
ECHO_STT_API_KEY=your_api_key_here
ECHO_STT_MODEL=whisper-1

# Text-to-Speech Configuration
ECHO_TTS_ENABLED=true
ECHO_TTS_PROVIDER=openai_compatible # mock | openai_compatible | local
ECHO_TTS_BASE_URL=https://api.openai.com/v1
ECHO_TTS_API_KEY=your_api_key_here
ECHO_TTS_VOICE=alloy
```
