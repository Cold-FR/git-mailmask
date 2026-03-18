#!/bin/bash

# Parse arguments
AUTO_PUSH=0
if [[ "$1" == "--auto-push" ]]; then
    AUTO_PUSH=1
fi

# =================================================
# Restore terminal state on Ctrl+C (SIGINT)
trap 'tput cnorm; echo -e "\n\033[1;31m[Cancelled] Exited by user.\033[0m"; exit 1' INT
# =================================================

# =================================================
#   Git Mail Mask
# =================================================
echo ""
echo "================================================="
echo -e "\033[1;37m   Git Mail Mask - Interactive Mode\033[0m"
echo "================================================="
echo ""

# Multi-selection menu (with pagination)
function show_multiselect_menu {
    local options=("$@")
    local total=${#options[@]}
    local cursor=0
    local page_size=10

    local selected=()
    for ((i=0; i<total; i++)); do selected[i]=0; done

    tput civis

    while true; do
        local current_page=$(( cursor / page_size + 1 ))
        local total_pages=$(( (total + page_size - 1) / page_size ))
        local start_idx=$(( (current_page - 1) * page_size ))
        local end_idx=$(( start_idx + page_size ))

        echo -e "\033[1;30m   --- Page $current_page / $total_pages --- (Arrows to scroll, Space to select, Enter to validate)\033[0m\033[K"

        for (( i=start_idx; i<end_idx; i++ )); do
            if [[ $i -lt $total ]]; then
                local prefix="  "
                [[ $i -eq $cursor ]] && prefix="\033[1;36m> \033[0m"

                local checkbox="( )"
                [[ ${selected[$i]} -eq 1 ]] && checkbox="\033[1;32m(X)\033[0m"

                echo -e "${prefix}${checkbox} ${options[$i]}\033[K"
            else
                # Clear padding
                echo -e "\033[K"
            fi
        done

        IFS= read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key2
            if [[ $key2 == '[A' ]]; then
                ((cursor--))
                [[ $cursor -lt 0 ]] && cursor=$((total - 1))
            elif [[ $key2 == '[B' ]]; then
                ((cursor++))
                [[ $cursor -ge $total ]] && cursor=0
            fi
        elif [[ "$key" == " " ]]; then
            if [[ ${selected[$cursor]} -eq 0 ]]; then
                selected[$cursor]=1
            else
                selected[$cursor]=0
            fi
        elif [[ -z "$key" ]]; then
            break
        fi

        echo -en "\033[$((page_size + 1))A"
    done

    tput cnorm

    SELECTED_REPOS=()
    for ((i=0; i<total; i++)); do
        if [[ ${selected[$i]} -eq 1 ]]; then
            SELECTED_REPOS+=("${options[$i]}")
        fi
    done
}

# Single selection menu
function show_singleselect_menu {
    local options=("$@")
    local total=${#options[@]}
    local cursor=0

    tput civis

    while true; do
        for (( i=0; i<total; i++ )); do
            if [[ $i -eq $cursor ]]; then
                echo -e "\033[1;36m> \033[1;32m(X)\033[0m ${options[$i]}\033[K"
            else
                echo -e "  ( ) ${options[$i]}\033[K"
            fi
        done

        IFS= read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key2
            if [[ $key2 == '[A' ]]; then
                ((cursor--))
                [[ $cursor -lt 0 ]] && cursor=$((total - 1))
            elif [[ $key2 == '[B' ]]; then
                ((cursor++))
                [[ $cursor -ge $total ]] && cursor=0
            fi
        elif [[ -z "$key" ]]; then
            SELECTED_INDEX=$cursor
            break
        fi

        echo -en "\033[${total}A"
    done

    tput cnorm
}

# 1. Dependencies
if ! command -v git-filter-repo &> /dev/null; then
    echo -e "\033[1;31m[Error] git-filter-repo not found. Run: pip install git-filter-repo\033[0m"
    exit 1
fi

# 2. Identity
echo -e "\033[1;33mNEW IDENTITY :\033[0m"
DEFAULT_NAME=""
DEFAULT_EMAIL=""
EMAIL_REGEX="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"

if command -v gh &> /dev/null; then
    tmp_login=$(mktemp)
    tmp_id=$(mktemp)

    # Async fetch
    (
        gh api user -q '.login' > "$tmp_login" 2>/dev/null
        gh api user -q '.id' > "$tmp_id" 2>/dev/null
    ) &
    pid=$!

    frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    tput civis

    # Loader
    while kill -0 $pid 2>/dev/null; do
        for frame in "${frames[@]}"; do
            if ! kill -0 $pid 2>/dev/null; then break; fi
            echo -en "\r\033[1;36m$frame\033[0m Fetching GitHub profile..."
            sleep 0.1
        done
    done

    echo -en "\r\033[K"
    tput cnorm

    DEFAULT_NAME=$(cat "$tmp_login")
    DEFAULT_ID=$(cat "$tmp_id")
    rm -f "$tmp_login" "$tmp_id"

    if [[ -n "$DEFAULT_NAME" && -n "$DEFAULT_ID" ]]; then
        DEFAULT_EMAIL="${DEFAULT_ID}+${DEFAULT_NAME}@users.noreply.github.com"
    fi
fi

if [[ -n "$DEFAULT_NAME" ]]; then
    read -r -p "- GitHub Username [Enter for: $DEFAULT_NAME] : " CORRECT_NAME
    CORRECT_NAME=${CORRECT_NAME:-$DEFAULT_NAME}

    while true; do
        read -r -p "- GitHub Email [Enter for: $DEFAULT_EMAIL] : " CORRECT_EMAIL
        CORRECT_EMAIL=${CORRECT_EMAIL:-$DEFAULT_EMAIL}

        if [[ "$CORRECT_EMAIL" =~ $EMAIL_REGEX ]]; then
            break
        else
            echo -e "  \033[1;31m[Error] Invalid email format. Please try again.\033[0m"
        fi
    done
else
    read -r -p "- GitHub Username (ex: Cold-FR) : " CORRECT_NAME

    while true; do
        read -r -p "- GitHub Email (ex: noreply@github.com) : " CORRECT_EMAIL
        if [[ "$CORRECT_EMAIL" =~ $EMAIL_REGEX ]]; then
            break
        else
            echo -e "  \033[1;31m[Error] Invalid email format. Please try again.\033[0m"
        fi
    done
fi
echo ""

# 3. Emails to replace
echo -e "\033[1;33mOLD EMAILS TO REPLACE :\033[0m"
echo -e "\033[1;30m   (Leave empty and press Enter to finish)\033[0m"
OLD_EMAILS=()

while true; do
    while true; do
        read -r -p "   > " OLD_EMAIL
        if [[ -z "$OLD_EMAIL" ]]; then
            break
        fi

        if [[ "$OLD_EMAIL" =~ $EMAIL_REGEX ]]; then
            OLD_EMAILS+=("$OLD_EMAIL")
        else
            echo -e "   \033[1;31m[Error] Invalid email format.\033[0m"
        fi
    done

    if [[ ${#OLD_EMAILS[@]} -gt 0 ]]; then
        break
    else
        echo -e "   \033[1;31m[Error] You must provide at least one email to replace. Please try again.\033[0m"
    fi
done
echo ""

# 4. Source selection
echo -e "\033[1;33mREPOSITORY SOURCE :\033[0m"
echo -e "\033[1;30m   (Arrows to choose, Enter to validate)\033[0m"

CURRENT_DIR_PATH=$(pwd)
SOURCE_OPTIONS=(
    "Enter a remote repository URL manually"
    "Connect to GitHub and select from my repositories"
    "Process the current directory ($CURRENT_DIR_PATH)"
    "Enter the path to a local repository manually"
)

REPOS=()
IS_LOCAL=0

while true; do
    show_singleselect_menu "${SOURCE_OPTIONS[@]}"
    echo ""

    if [[ "$SELECTED_INDEX" == "0" ]]; then
        read -r -p "Enter the repository URL : " SINGLE_REPO
        if [[ -z "$SINGLE_REPO" ]]; then
            echo -e "  \033[1;31m[Error] Empty URL. Please try again.\n\033[0m"
            continue
        fi
        REPOS+=("$SINGLE_REPO")
    elif [[ "$SELECTED_INDEX" == "1" ]]; then

        if ! command -v gh &> /dev/null; then
            echo -e "  \033[1;31m[Error] GitHub CLI (gh) not found. Please select another option.\n\033[0m"
            continue
        fi

        echo -e "\033[1;36mConnecting to GitHub and fetching repositories...\033[0m"
        mapfile -t ALL_GITHUB_REPOS < <(gh repo list --limit 100 --json url --jq '.[].url')

        if [[ ${#ALL_GITHUB_REPOS[@]} -eq 0 ]]; then
            echo -e "  \033[1;31m[Error] No repository found. Please select another option.\n\033[0m"
            continue
        fi

        echo -e "\n\033[1;33mSELECT REPOSITORIES TO CLEAN :\033[0m"

        show_multiselect_menu "${ALL_GITHUB_REPOS[@]}"

        REPOS+=("${SELECTED_REPOS[@]}")

        if [[ ${#REPOS[@]} -eq 0 ]]; then
            echo -e "  \033[1;31m[Error] No repository selected. Please try again.\n\033[0m"
            continue
        fi
    elif [[ "$SELECTED_INDEX" == "2" ]]; then
        if [[ ! -d ".git" ]]; then
            echo -e "  \033[1;31m[Error] Current directory is not a git repository. Please select another option.\n\033[0m"
            continue
        fi
        REPOS+=("$CURRENT_DIR_PATH")
        IS_LOCAL=1
    elif [[ "$SELECTED_INDEX" == "3" ]]; then
        read -r -p "Enter the path to your local repository : " SINGLE_REPO

        # Clean quotes if user drag & dropped a folder
        SINGLE_REPO="${SINGLE_REPO%\"}"
        SINGLE_REPO="${SINGLE_REPO#\"}"
        SINGLE_REPO="${SINGLE_REPO%\'}"
        SINGLE_REPO="${SINGLE_REPO#\'}"

        if [[ -z "$SINGLE_REPO" || ! -d "$SINGLE_REPO" ]]; then
            echo -e "  \033[1;31m[Error] Invalid path. Please try again.\n\033[0m"
            continue
        fi

        # Resolve to absolute path securely
        RESOLVED_PATH=$(cd "$SINGLE_REPO" && pwd)
        REPOS+=("$RESOLVED_PATH")
        IS_LOCAL=1
    fi

    if [[ ${#REPOS[@]} -gt 0 ]]; then
        break
    fi
done
echo ""

# 5. Process filter-repo
echo -e "\033[1;36mSTARTING CLEANUP (${#REPOS[@]} repository(ies) selected)...\033[0m"
ORIGINAL_DIR=$(pwd)
WORK_DIR="git_mailmask_temp"
mkdir -p "$WORK_DIR"

# We use absolute path for mailmap since we will CD into repositories
MAILMAP_FILE="$ORIGINAL_DIR/$WORK_DIR/mailmap.txt"
: > "$MAILMAP_FILE"
for old_email in "${OLD_EMAILS[@]}"; do
    echo "$CORRECT_NAME <$CORRECT_EMAIL> <$old_email>" >> "$MAILMAP_FILE"
done

for REPO in "${REPOS[@]}"; do
    echo "-------------------------------------------------"

    if [[ $IS_LOCAL -eq 1 ]]; then
        echo -e "\033[1;33mProcessing local repository : $REPO\033[0m"
        cd "$REPO" || continue
        if [[ ! -d ".git" ]]; then
            echo -e "\033[1;31m[Error] Not a git repository. Skipping.\033[0m"
            cd "$ORIGINAL_DIR" || exit
            continue
        fi
    else
        echo -e "\033[1;33mProcessing remote repository : $REPO\033[0m"
        cd "$ORIGINAL_DIR" || exit
        cd "$WORK_DIR" || continue

        git clone "$REPO"
        FOLDER_NAME=$(basename "$REPO" .git)
        cd "$FOLDER_NAME" || continue

        # Check branches
        for remote in $(git branch -r | grep -v '\->'); do
            git branch --track "${remote#origin/}" "$remote" 2>/dev/null || true
        done
    fi

    # Backup origin URL because filter-repo deletes remotes
    ORIGIN_URL=$(git remote get-url origin 2>/dev/null)

    # Apply mailmap
    git filter-repo --mailmap "$MAILMAP_FILE" --force

    # Restore origin
    if [[ -n "$ORIGIN_URL" ]]; then
        git remote add origin "$ORIGIN_URL"
    elif [[ $IS_LOCAL -eq 0 ]]; then
        git remote add origin "$REPO"
    fi

    # Push Execution
    echo -e "\n\033[1;32mHistory successfully rewritten locally!\033[0m"

    if [[ $AUTO_PUSH -eq 1 ]]; then
        echo -e "\033[1;36mAuto-push flag detected. Pushing to remote...\n\033[0m"
        git push --force --tags origin 'refs/heads/*' || git push --force --tags
    else
        read -r -p "Do you want to force push to the remote? [Y/n] " PUSH_CONFIRM
        if [[ "$PUSH_CONFIRM" =~ ^[Nn]$ ]]; then
            echo -e "\033[1;30mSkipping push for this repository.\033[0m"
        else
            echo ""
            git push --force --tags origin 'refs/heads/*' || git push --force --tags
        fi
    fi

    cd "$ORIGINAL_DIR" || exit
done

# 6. Cleanup
cd "$ORIGINAL_DIR" || exit
rm -rf "$WORK_DIR"

echo ""
echo "================================================="
echo -e "\033[1;32mOPERATION COMPLETED SUCCESSFULLY !\033[0m"
echo "================================================="