# OpenAI Integration Setup

This folder contains the OpenAI integration for transcription and summarization.

## Setup Instructions

1. **Get an OpenAI API Key**

   - Go to https://platform.openai.com/api-keys
   - Create a new API key
   - Copy the key (you won't be able to see it again!)

2. **Add Your API Key**

   - Open `OpenAIConfig.swift`
   - Replace `"YOUR_API_KEY_HERE"` with your actual API key:

   ```swift
   static let apiKey = "sk-proj-..."
   ```

3. **Pick the Models**

   - Ensure `transcriptionModel` points at your preferred Whisper model (e.g. `"gpt-4o-transcribe"`)
   - Set `summaryModel` to a chat-capable model (defaults to `"gpt-4o-mini"` in `OpenAIConfig.swift`)

4. **Important: Keep Your API Key Private**
   - `OpenAIConfig.swift` is already in `.gitignore`
   - Never commit your API key to version control
   - Never share your API key publicly

## How It Works

- **Transcription**: Uses OpenAI's Whisper model to convert audio to text
- **Summarization**: Uses GPT-4 to create structured meeting summaries
- **Automatic**: Runs automatically after each recording completes

## Cost Estimate

- Whisper transcription: ~$0.006 per minute of audio
- GPT-4 summarization: ~$0.01-0.03 per meeting (depending on length)

## Troubleshooting

If transcription fails:

1. Check that your API key is correct
2. Ensure you have credits in your OpenAI account
3. Check the Xcode console for detailed error messages
