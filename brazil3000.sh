#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_FILE="$SCRIPT_DIR/review.txt"
WORDS_FILE="$SCRIPT_DIR/brazilian_words.txt"
IRREGULAR_VERBS_FILE="$SCRIPT_DIR/irregular_verbs.txt"
ENV_FILE="$SCRIPT_DIR/.env"

#SELECTED_MODEL="gemma2-9b-it"
SELECTED_MODEL="moonshotai/kimi-k2-instruct"
SYSTEM_PROMPT="You are an expert but encouraging Brazilian Portuguese tutor. Always use BRAZILIAN Portuguese (never European Portuguese). Be a bit lenient and flexible, focus on good communication. Remember: você uses 3rd person conjugations (você tem, not você tens). Ignore missing accents in student answers. Give direct, concise responses without extra formatting or explanations."

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
        'Brazil 3000 - Portuguese CLI' 'AI-Powered Learning Tool'
    echo
}


main_menu() {
    while true; do
        gum style --foreground 34 "Main Menu:"
        
        # Show review count if file exists
        if [[ -f "$REVIEW_FILE" && -s "$REVIEW_FILE" ]]; then
            local count=$(wc -l < "$REVIEW_FILE")
            choice=$(gum choose "Practice Mode" "Exercise Conjugations" "Review Mode ($count items)" "Exit")
        else
            choice=$(gum choose "Practice Mode" "Exercise Conjugations" "Review Mode" "Exit")
        fi
        
        case "$choice" in
            "Practice Mode") practice_mode;;
            "Exercise Conjugations") verb_mode;;
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
        
        local english="$sentence_data"
        
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
            gum style --foreground 226 "    My feedback: $(echo "$evaluation" | sed 's/INCORRECT: //')"
            echo "$english" >> "$REVIEW_FILE"
            gum style --foreground 226 "    Added to review"
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
            gum style --foreground 34 "    Removed from review"
        else
            gum style --foreground 226 "  ✗ Your answer: $user_translation"
            gum style --foreground 226 "    My feedback: $(echo "$evaluation" | sed 's/INCORRECT: //')"
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

verb_mode() {
    echo "Exercise Conjugations"
    echo "Select tenses to practice:"
    echo
    
    # Multi-select tenses
    local selected_tenses=$(gum choose --no-limit \
        "Present (Presente)" \
        "Preterite (Pretérito Perfeito)" \
        "Imperfect (Pretérito Imperfeito)" \
        "Future (Futuro)" \
        "Conditional (Condicional)" \
        "Present Subjunctive (Presente do Subjuntivo)")
    
    [[ -z "$selected_tenses" ]] && { echo "No tenses selected"; return; }
    
    echo
    echo "Select verb difficulty (frequency):"
    local verb_tiers=$(gum choose --no-limit \
        "Tier 1 (most common: ser, ter, estar, fazer)" \
        "Tier 2 (common: pedir, ouvir, sentir)" \
        "Tier 3 (moderate: preferir, construir)" \
        "Tier 4 (less common: requerer, prever)" \
        "Tier 5 (uncommon: antever, predizer)" \
        "Tier 6 (rare: jazer, liquefazer)")
    
    [[ -z "$verb_tiers" ]] && { echo "No tiers selected"; return; }
    
    echo
    echo "Include regular verbs?"
    local include_regular=$(gum choose "Irregular verbs only" "Include regular verbs")
    
    echo
    verb_practice_loop "$selected_tenses" "$verb_tiers" "$include_regular"
}

verb_practice_loop() {
    local selected_tenses="$1"
    local verb_tiers="$2"
    local include_regular="$3"
    
    local correct_count=0
    local total_count=0
    
    gum style --foreground 34 "Exercise Conjugations Started"
    gum style --foreground 244 --faint "Selected tenses: $(echo "$selected_tenses" | tr '\n' ', ' | sed 's/, $//')"
    echo "Type 'quit' or 'exit' to return"
    echo
    
    while true; do
        local selected_verb=$(get_random_verb_from_tiers "$verb_tiers")
        gum spin --spinner line --title "Generating..." -- sleep 1
        local verb_exercise=$(generate_verb_exercise "$selected_tenses" "$selected_verb" "$include_regular")
        
        [[ -z "$verb_exercise" ]] && { echo "Error generating exercise. Trying again..."; continue; }
        
        local infinitive=$(echo "$verb_exercise" | grep "INFINITIVE:" | sed 's/INFINITIVE: //')
        local tense=$(echo "$verb_exercise" | grep "TENSE:" | sed 's/TENSE: //')
        local person=$(echo "$verb_exercise" | grep "PERSON:" | sed 's/PERSON: //')
        local correct_form=$(echo "$verb_exercise" | grep "CONJUGATION:" | sed 's/CONJUGATION: //')
        
        
        # Convert tense to short form
        local tense_short=$(echo "$tense" | sed 's/Present.*/present/; s/Preterite.*/preterite/; s/Imperfect.*/imperfect/; s/Future.*/future/; s/Conditional.*/conditional/; s/Present Subjunctive.*/subjunctive/')
        
        # Show context with actual AI response data
        gum style --foreground 244 --faint "Conjugate: $infinitive ($tense_short)"
        echo
        
        user_conjugation=$(gum input --value "$person " --placeholder "$person [conjugated verb]" --prompt "→ ")
        [[ "$user_conjugation" == "quit" || "$user_conjugation" == "exit" ]] && break
        
        # Extract just the verb part (remove the pronoun)
        local user_verb=$(echo "$user_conjugation" | sed "s/^$person //")
        [[ "$user_verb" == "$user_conjugation" ]] && user_verb="" # If no pronoun was there
        
        echo
        ((total_count++))
        
        if [[ "$user_verb" == "$correct_form" ]]; then
            ((correct_count++))
            gum style --foreground 34 "✓ $user_conjugation"
            gum style --foreground 34 --faint "  Perfect!"
        else
            gum style --foreground 226 "✗ $user_conjugation"
            gum style --foreground 34 "✓ $person $correct_form"
            
            # Show learning tip for common mistakes
            case "$infinitive" in
                "ter"|"vir"|"ver")
                    if [[ "$person" == "você" && "$user_verb" == *"s"* ]]; then
                        gum style --foreground 244 --faint "  💡 Remember: 'você' uses 3rd person (like ele/ela)"
                    fi
                    ;;
            esac
        fi
        
        # Show session progress
        local percentage=$((correct_count * 100 / total_count))
        gum style --foreground 244 --faint "  Session: $correct_count/$total_count correct ($percentage%)"
        
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
    done
}

get_random_word() {
    local limit=$1
    local line_count=$(head -n "$limit" "$WORDS_FILE" | wc -l)
    local random_line=$((RANDOM % line_count + 1))
    head -n "$limit" "$WORDS_FILE" | sed -n "${random_line}p"
}

get_random_verb_from_tiers() {
    local verb_tiers="$1"
    
    # Extract tier numbers from selection
    local tier_numbers=""
    while IFS= read -r tier_line; do
        local tier_num=$(echo "$tier_line" | sed 's/Tier \([0-9]\).*/\1/')
        tier_numbers="$tier_numbers $tier_num"
    done <<< "$verb_tiers"
    
    # Get all verbs from selected tiers
    local temp_file=$(mktemp)
    for tier in $tier_numbers; do
        grep "^$tier " "$IRREGULAR_VERBS_FILE" >> "$temp_file"
    done
    
    # Select random verb from filtered list
    local verb_count=$(wc -l < "$temp_file")
    if [[ $verb_count -eq 0 ]]; then
        rm -f "$temp_file"
        echo "ser" # fallback
        return
    fi
    
    local random_line=$((RANDOM % verb_count + 1))
    local selected_verb=$(sed -n "${random_line}p" "$temp_file" | cut -d' ' -f2)
    rm -f "$temp_file"
    
    echo "$selected_verb"
}

call_groq_api() {
    local prompt="$1"
    
    # Escape prompts for JSON - handle newlines and quotes
    local escaped_system=$(printf '%s' "$SYSTEM_PROMPT" | sed 's/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
    local escaped_prompt=$(printf '%s' "$prompt" | sed 's/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
    
    # JSON with system and user messages
    local json_payload="{\"model\":\"$SELECTED_MODEL\",\"messages\":[{\"role\":\"system\",\"content\":\"$escaped_system\"},{\"role\":\"user\",\"content\":\"$escaped_prompt\"}]}"
    
    local response=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload")
    
    # Simple error check
    if echo "$response" | grep -q '"error"'; then
        gum style --foreground 196 "API Error occurred"
        return 1
    fi
    
    # Extract content with better parsing that handles escaped characters
    local content
    if command -v python3 >/dev/null 2>&1; then
        content=$(echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except:
    pass
")
    else
        # Fallback: improved sed parsing
        content=$(echo "$response" | sed -n 's/.*"content":"\(.*\)","refusal".*/\1/p' | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g')
        if [[ -z "$content" ]]; then
            content=$(echo "$response" | sed -n 's/.*"content":"\([^"]*\)".*/\1/p' | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g')
        fi
    fi
    
    if [[ -z "$content" ]]; then
        gum style --foreground 196 "Error: Empty response"
        return 1
    fi
    
    echo "$content"
}

generate_sentence() {
    local word="$1"
    local difficulty="$2"
    local prompt="Create an English sentence for Portuguese translation practice using the word \"$word\".

Requirements:
- Write ONLY in English - NO Portuguese words in the English sentence
- Use common English vocabulary only
- The sentence should translate naturally to Portuguese using \"$word\"
- $difficulty level: Easy=very simple present tense, Medium=simple past/future, Hard=compound sentences
- Length: 6-12 words (keep it short and clear)

Respond with just the English sentence (no labels or formatting)."
    
    call_groq_api "$prompt"
}

generate_verb_exercise() {
    local selected_tenses="$1"
    local selected_verb="$2"
    local include_regular="$3"
    
    # Pick random tense from selected tenses
    local tenses_array=($selected_tenses)
    local random_tense_index=$((RANDOM % ${#tenses_array[@]}))
    local chosen_tense="${tenses_array[$random_tense_index]}"
    
    # Pick random person
    local persons=("eu" "você" "ele" "ela" "nós" "vocês" "eles" "elas")
    local random_person_index=$((RANDOM % ${#persons[@]}))
    local chosen_person="${persons[$random_person_index]}"
    
    local prompt="Conjugate the verb \"$selected_verb\" for the person \"$chosen_person\" in the tense \"$chosen_tense\".

Format your response as exactly four lines:
INFINITIVE: $selected_verb
TENSE: $chosen_tense
PERSON: $chosen_person
CONJUGATION: [correct conjugated form of $selected_verb for $chosen_person in $chosen_tense]

Example:
INFINITIVE: ter
TENSE: Present
PERSON: você
CONJUGATION: tem"
    
    call_groq_api "$prompt"
}

evaluate_translation() {
    local english="$1"
    local user_answer="$2"
    local prompt="Evaluate this Portuguese translation:

English: $english
User translation: $user_answer

Guidelines:
- If the meaning is understood: CORRECT (even with minor errors)
- Ignore: missing accents, minor spelling, alternative word choices
- Remember: communication over perfection

Response format:
CORRECT: Great job! [optional: minor tip if needed]
INCORRECT: [only if meaning is completely wrong - provide correct Portuguese translation]

Be encouraging. Keep under 25 words."
    
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