// Wrapper around expo-speech-recognition that fails gracefully when the native
// module isn't available (e.g. running inside Expo Go, where speech recognition
// requires a custom dev build). Screens call isVoiceAvailable() to decide
// whether to show the mic button.

let Speech = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  Speech = require('expo-speech-recognition');
} catch {
  Speech = null;
}

export function isVoiceAvailable() {
  return Speech != null;
}

export const VoiceInput = {
  // Subscribe to transcription results + end/error. Returns a cleanup function.
  subscribe(onResult, onEnd) {
    if (!Speech) return () => {};
    const subs = [];
    subs.push(
      Speech.ExpoSpeechRecognitionModule.addListener('result', (event) => {
        const transcript = event.results?.[0]?.transcript;
        if (transcript) onResult(transcript);
      }),
    );
    subs.push(Speech.ExpoSpeechRecognitionModule.addListener('end', onEnd));
    subs.push(Speech.ExpoSpeechRecognitionModule.addListener('error', onEnd));
    return () => subs.forEach((s) => s.remove());
  },

  async start() {
    if (!Speech) return;
    try {
      const perms = await Speech.ExpoSpeechRecognitionModule.requestPermissionsAsync();
      if (!perms.granted) return;
      Speech.ExpoSpeechRecognitionModule.start({
        lang: 'en-US',
        interimResults: true,
        continuous: false,
      });
    } catch {
      // ignore
    }
  },

  async stop() {
    if (!Speech) return;
    try {
      Speech.ExpoSpeechRecognitionModule.stop();
    } catch {
      // ignore
    }
  },
};
