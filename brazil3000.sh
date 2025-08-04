#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_FILE="$SCRIPT_DIR/review.txt"
WORDS_FILE="$SCRIPT_DIR/brazilian_words.txt"
ENV_FILE="$SCRIPT_DIR/.env"

SELECTED_MODEL="gemma2-9b-it"

check_dependencies() {
    if ! command -v gum >/dev/null 2>&1; then
        echo "Missing requirement: gum"
        echo "Install: brew install gum"
        exit 1
    fi
}

load_environment() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "Missing .env file"
        echo "Create it with: GROQ_API_KEY=your_key_here"
        exit 1
    fi
    
    source "$ENV_FILE"
    
    if [[ -z "$GROQ_API_KEY" ]]; then
        echo "Missing GROQ_API_KEY in .env file"
        exit 1
    fi
}

show_header() {
    echo
    gum style \
        --foreground 226 --border-foreground 34 --border double \
        --align center --width 50 --margin "1 0" --padding "2 4" \
        'Brazil 2000 - Portuguese CLI' 'AI-Powered Learning Tool'
    echo
}


main_menu() {
    while true; do
        gum style --foreground 34 "Main Menu:"
        
        # Show review count if file exists
        if [[ -f "$REVIEW_FILE" && -s "$REVIEW_FILE" ]]; then
            local count=$(wc -l < "$REVIEW_FILE")
            choice=$(gum choose "Practice Mode" "Review Mode ($count items)" "Exit")
        else
            choice=$(gum choose "Practice Mode" "Review Mode" "Exit")
        fi
        
        case "$choice" in
            "Practice Mode") practice_mode;;
            *"Review Mode"*) review_mode;;
            "Exit") gum style --foreground 226 "Goodbye!"; exit 0;;
        esac
    done
}

practice_mode() {
    gum style --foreground 34 "Select Difficulty:"
    difficulty=$(gum choose \
        "Easy (top 1000 words)" \
        "Medium (top 2000 words)" \
        "Hard (full 3000 vocabulary)")
    
    case "$difficulty" in
        "Easy"*) practice_loop "Easy" 1000;;
        "Medium"*) practice_loop "Medium" 2000;;
        "Hard"*) practice_loop "Hard" 3000;;
    esac
}

practice_loop() {
    local difficulty=$1
    local word_limit=$2
    
    echo "$difficulty practice mode"
    echo "Type 'quit' or 'exit' to return"
    echo
    
    while true; do
        local word=$(get_random_word $word_limit)
        gum spin --spinner line --title "Generating..." -- sleep 1
        local sentence_data=$(generate_sentence "$word" "$difficulty")
        
        [[ -z "$sentence_data" ]] && { echo "Error generating sentence. Trying again..."; continue; }
        
        local english=$(echo "$sentence_data" | grep "ENGLISH:" | sed 's/ENGLISH: //')
        
        echo "$english"
        echo
        
        user_translation=$(gum input --placeholder "Portuguese translation...")
        [[ "$user_translation" == "quit" || "$user_translation" == "exit" ]] && break
        
        echo
        gum spin --spinner dot --title "Checking..." -- sleep 1
        local evaluation=$(evaluate_translation "$english" "$user_translation")
        
        if echo "$evaluation" | grep -q "^CORRECT"; then
            gum style --foreground 34 "  ✓ Your answer: $user_translation"
            gum style --foreground 34 "    $(echo "$evaluation" | sed 's/CORRECT: //')"
        else
            gum style --foreground 226 "  ✗ Your answer: $user_translation"  
            gum style --foreground 226 "    $(echo "$evaluation" | sed 's/INCORRECT: //')"
            echo "$english" >> "$REVIEW_FILE"
            echo "Added to review"
        fi
        
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
    done
}

review_mode() {
    [[ ! -f "$REVIEW_FILE" || ! -s "$REVIEW_FILE" ]] && { echo "No sentences to review!"; return; }
    
    echo "Review mode"
    echo "Type 'quit' or 'exit' to return"
    echo
    
    local temp_file=$(mktemp)
    
    while [[ -s "$REVIEW_FILE" ]]; do
        local english=$(head -n 1 "$REVIEW_FILE")
        
        echo "$english"
        echo
        
        user_translation=$(gum input --placeholder "Portuguese translation...")
        [[ "$user_translation" == "quit" || "$user_translation" == "exit" ]] && { rm -f "$temp_file"; break; }
        
        echo
        gum spin --spinner dot --title "Checking..." -- sleep 1
        local evaluation=$(evaluate_translation "$english" "$user_translation")
        
        if echo "$evaluation" | grep -q "^CORRECT"; then
            gum style --foreground 34 "  ✓ Your answer: $user_translation"
            gum style --foreground 34 "    $(echo "$evaluation" | sed 's/CORRECT: //')"
            tail -n +2 "$REVIEW_FILE" > "$temp_file" && mv "$temp_file" "$REVIEW_FILE"
            echo "Removed from review"
        else
            gum style --foreground 226 "  ✗ Your answer: $user_translation"
            gum style --foreground 226 "    $(echo "$evaluation" | sed 's/INCORRECT: //')"
            tail -n +2 "$REVIEW_FILE" > "$temp_file"
            echo "$english" >> "$temp_file"
            mv "$temp_file" "$REVIEW_FILE"
        fi
        
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
    done
    
    [[ ! -s "$REVIEW_FILE" ]] && echo "All sentences completed!"
}

get_random_word() {
    local limit=$1
    local line_count=$(head -n "$limit" "$WORDS_FILE" | wc -l)
    local random_line=$((RANDOM % line_count + 1))
    head -n "$limit" "$WORDS_FILE" | sed -n "${random_line}p"
}

call_groq_api() {
    local prompt="$1"
    
    # Use jq to properly escape JSON if available, otherwise manual escaping
    local json_payload
    if command -v jq >/dev/null 2>&1; then
        json_payload=$(jq -n --arg model "$SELECTED_MODEL" --arg content "$prompt" '{
            model: $model,
            messages: [
                {
                    role: "user",
                    content: $content
                }
            ]
        }')
    else
        # Manual JSON escaping for special characters
        local escaped_prompt=$(printf '%s' "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
        json_payload=$(cat <<EOF
{
    "model": "$SELECTED_MODEL",
    "messages": [
        {
            "role": "user",
            "content": "$escaped_prompt"
        }
    ]
}
EOF
)
    fi
    
    local response=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload")
    
    # Check for errors in response
    if echo "$response" | grep -q '"error"'; then
        local error_msg
        if command -v jq >/dev/null 2>&1; then
            error_msg=$(echo "$response" | jq -r '.error.message // .error')
        else
            error_msg=$(echo "$response" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
        fi
        gum style --foreground 196 "API Error: $error_msg"
        return 1
    fi
    
    local content
    if command -v jq >/dev/null 2>&1; then
        content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
    else
        content=$(echo "$response" | sed -n 's/.*"content":"\([^"]*\)".*/\1/p' | head -n 1)
    fi
    
    [[ -z "$content" || "$content" == "null" ]] && { gum style --foreground 196 "Error: Empty response from API"; return 1; }
    
    echo "$content"
}

generate_sentence() {
    local word="$1"
    local difficulty="$2"
    local prompt="You are creating English sentences for Portuguese translation practice.

Task: Create an English sentence that can be translated to Portuguese using the word \"$word\"

CRITICAL RULES:
1. Write ONLY in English - NO Portuguese words in the English sentence
2. Use common English vocabulary only
3. The sentence should translate naturally to Portuguese using \"$word\"
4. $difficulty level: Easy=very simple present tense, Medium=simple past/future, Hard=compound sentences
5. Length: 6-12 words (keep it short and clear)

Example format:
ENGLISH: The organization helps people in the community.
PORTUGUESE: A organização ajuda pessoas na comunidade.

Your response:"
    
    call_groq_api "$prompt"
}

evaluate_translation() {
    local english="$1"
    local user_answer="$2"
    local prompt="Evaluate this Portuguese translation. Be consistent and fair.

English: $english
User translation: $user_answer

Guidelines:
- If meaning is clear and grammar is mostly correct: CORRECT
- Consider: meaning accuracy, basic grammar, Brazilian Portuguese usage
- Ignore minor spelling/accent errors. Be lenient to encourage learning like a good tutor. 

Response format:
CORRECT: [brief positive feedback]
INCORRECT: [provide correct translation]

Keep response under 30 words."
    
    call_groq_api "$prompt"
}

main() {
    check_dependencies
    show_header
    load_environment
    main_menu
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi