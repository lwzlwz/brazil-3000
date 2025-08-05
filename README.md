# Brazil 3000 - Portuguese Learning CLI

AI-powered Brazilian Portuguese learning tool with interactive translation practice.

[![Screenshot-2025-08-04-at-18-09-41.png](https://i.postimg.cc/RC8sBdp2/Screenshot-2025-08-04-at-18-09-41.png)](https://postimg.cc/jCHQ6Hbh)

## Features

- **Practice Mode**: Translate English sentences to Portuguese with AI feedback
- **Exercise Conjugations**: Practice irregular verb conjugations with tier-based difficulty
- **Review Mode**: Retry previously incorrect translations until mastered
- **Smart Difficulty**: Easy (simple present tense), Medium (past/future tense), Hard (compound sentences)
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
- `irregular_verbs.txt` - 250+ irregular verbs organized by frequency tiers
- `review.txt` - Your personal review list (auto-generated)
- `.env` - Your API configuration (not tracked)

## Backlog / Ideas

- append feedback/corrections to feedback.txt file (personal so in .gitignore)
- add user menu item to summarise tutor feedback (via LLM call) to reflect on and improve learning 
- correct/incorrect feedback in review mode is too rigid
