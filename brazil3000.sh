#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_FILE="$SCRIPT_DIR/review.txt"
WORDS_FILE="$SCRIPT_DIR/brazilian_words.txt"
IRREGULAR_VERBS_FILE="$SCRIPT_DIR/irregular_verbs.txt"
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
    
    echo "Starting verb conjugation practice"
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
        
        echo "$infinitive ($tense_short)"
        echo
        
        user_conjugation=$(gum input --value "$person " --placeholder "$person ...")
        [[ "$user_conjugation" == "quit" || "$user_conjugation" == "exit" ]] && break
        
        # Extract just the verb part (remove the pronoun)
        local user_verb=$(echo "$user_conjugation" | sed "s/^$person //")
        [[ "$user_verb" == "$user_conjugation" ]] && user_verb="" # If no pronoun was there
        
        echo
        if [[ "$user_verb" == "$correct_form" ]]; then
            gum style --foreground 34 "  ✓ Correct: $user_conjugation"
        else
            gum style --foreground 226 "  ✗ Your answer: $user_conjugation"
            gum style --foreground 34 "    Correct: $person $correct_form"
        fi
        
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
    local prompt="You are creating English sentences for BRAZILIAN Portuguese translation practice.

Task: Create an English sentence that can be translated to BRAZILIAN Portuguese using the word \"$word\"

CRITICAL RULES:
1. Write ONLY in English - NO Portuguese words in the English sentence
2. Use common English vocabulary only
3. The sentence should translate naturally to BRAZILIAN Portuguese using \"$word\"
4. $difficulty level: Easy=very simple present tense, Medium=simple past/future, Hard=compound sentences
5. Length: 6-12 words (keep it short and clear)
6. BRAZILIAN Portuguese ONLY (not European Portuguese)

Example format:
ENGLISH: The organization helps people in the community.
PORTUGUESE: A organização ajuda pessoas na comunidade.

Your response:"
    
    call_groq_api "$prompt"
}

generate_verb_exercise() {
    local selected_tenses="$1"
    local selected_verb="$2"
    local include_regular="$3"
    local prompt="Generate a BRAZILIAN Portuguese verb conjugation exercise.

Selected tenses: $selected_tenses
Use this specific verb: $selected_verb
Verb types: $include_regular

CRITICAL: Use BRAZILIAN Portuguese only (NOT European Portuguese)
- No \"vós\" - it doesn't exist in Brazilian Portuguese
- Use Brazilian conjugations and vocabulary
- IMPORTANT: \"você\" uses the same conjugation as \"ele/ela\" (3rd person singular)
- NEVER use \"tens\" with \"você\" - use \"tem\" (Brazilian Portuguese)

BRAZILIAN Portuguese conjugation rules:
- eu: 1st person singular
- você: 3rd person singular (same as ele/ela)
- ele/ela: 3rd person singular
- nós: 1st person plural
- vocês: 3rd person plural (same as eles/elas)
- eles/elas: 3rd person plural

Requirements:
- Use the verb \"$selected_verb\" as specified
- Choose one of the selected tenses randomly: $selected_tenses
- Pick a random person (eu, você, ele/ela, nós, vocês, eles/elas)
- Provide the correct BRAZILIAN Portuguese conjugation for \"$selected_verb\"

Format your response as exactly four lines:
INFINITIVE: $selected_verb
TENSE: [chosen tense name from the selected tenses]
PERSON: [person - eu, você, ele/ela, nós, vocês, eles/elas]
CONJUGATION: [correct conjugated form of $selected_verb]

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
    local prompt="Evaluate this BRAZILIAN Portuguese translation. Be very lenient and encouraging like a supportive tutor.

English: $english
User translation: $user_answer

CRITICAL: Evaluate using BRAZILIAN Portuguese standards (NOT European Portuguese)

LENIENT GUIDELINES:
- If the meaning is understood: CORRECT (even with minor errors)
- Ignore: missing accents, minor spelling, alternative word choices
- Only mark INCORRECT if meaning is completely wrong or incomprehensible
- Remember: communication over perfection
- Use BRAZILIAN Portuguese forms and vocabulary in corrections

Examples of what should be CORRECT:
- \"cafe\" instead of \"café\" (missing accent)
- \"mais jovem\" vs \"mais novo\" (both mean youngest)
- \"e\" instead of \"é\" (missing accent but clear meaning)

Response format:
CORRECT: Great job! [optional: minor tip if needed]
INCORRECT: [only if meaning is completely wrong - provide BRAZILIAN Portuguese correction]

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