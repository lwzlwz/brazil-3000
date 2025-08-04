# Brazil 3000 - Portuguese Learning CLI

AI-powered Brazilian Portuguese learning tool with interactive translation practice.

## Features

- **Practice Mode**: Translate English sentences to Portuguese with AI feedback
- **Review Mode**: Retry previously incorrect translations until mastered
- **Smart Difficulty**: Easy (1000 words), Medium (2000 words), Hard (3000 words)
- **Clean Interface**: Simple, distraction-free learning experience

## Requirements

- [Gum](https://github.com/charmbracelet/gum) - Modern CLI interface
- [Groq API Key](https://console.groq.com/) - Free AI translation service

## Installation

1. Install Gum:
   ```bash
   brew install gum
   ```

2. Clone and setup:
   ```bash
   git clone https://github.com/lwzlwz/brazil-3000.git
   cd brazil-3000
   cp .env.example .env
   ```

3. Add your Groq API key to `.env`:
   ```
   GROQ_API_KEY=your_key_here
   ```

## Usage

```bash
./brazil3000.sh
```

Choose your difficulty, translate sentences, and improve your Portuguese! Incorrect answers automatically go to your review list for focused practice.

## Files

- `brazil3000.sh` - Main application
- `brazilian_words.txt` - 3000 Portuguese words (frequency ordered)  
- `review.txt` - Your personal review list (auto-generated)
- `.env` - Your API configuration (not tracked)