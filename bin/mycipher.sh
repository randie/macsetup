#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# mycipher.sh — Secure Encryption & Integrity Verification Utility
# ------------------------------------------------------------------------------
#
# Usage: mycipher.sh {encrypt|decrypt|verify} [-p pass] [-o out] <file|directory>
#
# Commands: encrypt | verify | decrypt
#
# Workflow:
#   1. encrypt: Run 'encrypt' on your target file or directory.
#      ╰─❯ mycipher.sh encrypt my-file.pdf     # => x-my-file.pdf
#      ╰─❯ mycipher.sh encrypt my-directory    # => x-my-directory
#
#   2. 1Password: MANUALLY copy the resulting SHA-256 hash and the encryption 
#      password (from ~/.mycipher) into your 1Password entry for this
#      encrypted file or directory.
#
#   3. upload: Move the encrypted (x-*) file to your cloud storage.
#
#   4. verify: (Every so often) Run 'verify' on your x-* files in the cloud to
#      to see if any bit rot has corrupted your encrypted files. This will
#      compare a newly generated hash with the one you saved in 1Password.
#      ╰─❯ mycipher.sh verify -v <hash-from-1password> x-my-directory
#
#   5. decrypt: Download a copy of an encrypted file/directory, and run
#      'decrypt -v <hash>' on it.
#      ╰─❯ mycipher.sh decrypt -v <hash-from-1password> x-my-directory
#
# How it works:
#   1. Password Logic: 
#      - Uses -p <password> if provided (wrap complex strings in single quotes '').
#      - else, reads the first line of ~/.mycipher as the password
#      - else, prompts via secure hidden terminal input
#
#   2. Encryption Engine: (uses /opt/homebrew/bin/openssl)
#      - Algorithm: AES-256-CBC (for Maximum Portability).
#      - Key Derivation: PBKDF2 with a random 8-byte salt (stored in header).
#      - Integrity: External verification via SHA-256 hashing.
#
#   3. Logic Flow: 
#      - Directories: Automatically streamed through 'tar' before encryption.
#      - Files: Encrypted directly as binary blobs.
#      - Decryption: Uses 'file' utility to detect tar headers in the resulting
#        plaintext, triggering automatic extraction if a directory is found.
#
# ------------------------------------------------------------------------------

# --- Global Configuration & State ---

readonly OPENSSL="/opt/homebrew/bin/openssl"
readonly PW_FILE="$HOME/.mycipher"

CMD=""          # 'encrypt', 'decrypt', or 'verify'
OPT_PASS=""     # Password from -p flag
OPT_OUT=""      # Output filename from -o flag
OPT_HASH=""     # Expected hash for verification (-v)
TARGET=""          # The target file or directory parameter
PASSWORD=""     # The final resolved password string

# --- Helper Functions ---

usage() {
    echo "Usage: $0 {encrypt|decrypt|verify} [-p password] [-o output_file] [-v expected_hash] <parameter>"
    exit 1
}

validate_target() {
    local target=$1
    if [[ -z "$target" ]]; then
        echo "Error: No file or directory specified."
        usage
    fi
    if [[ ! -e "$target" ]]; then
        echo "Error: Target '$target' does not exist."
        exit 1
    fi
}

get_password() {
    local pass_arg=$1
    if [[ -n "$pass_arg" ]]; then
        echo "$pass_arg"
    elif [[ -f "$PW_FILE" ]]; then
        head -n 1 "$PW_FILE" | xargs
    else
        read -rs -p "Enter password: " manual_pass
        echo "$manual_pass" >&2
        echo "$manual_pass"
    fi
}

parse_command_line() {
    CMD=$1
    shift || usage
    
    while getopts "p:o:v:" opt; do
        case $opt in
            p) OPT_PASS=$OPTARG ;;
            o) OPT_OUT=$OPTARG ;;
            v) OPT_HASH=$OPTARG ;;
            *) usage ;;
        esac
    done
    shift $((OPTIND-1))
    
    TARGET=$1
}

# --- Core Logic Functions ---

verify_target() {
    local target=$1
    local expected=$2

    if [[ ! -f "$target" ]]; then
        echo "Error: Cannot verify. '$target' is not a file."
        return 1
    fi

    local actual=$($OPENSSL dgst -sha256 "$target" | awk '{print $NF}')

    echo "--- Integrity Report for: $target ---"
    
    if [[ -n "$expected" ]]; then
        if [[ "$actual" == "$expected" ]]; then
            echo "SUCCESS: Integrity confirmed. Hash matches."
            echo "---------------------------------------"
            return 0
        else
            echo "ACTUAL:   $actual"
            echo "EXPECTED: $expected"
            echo "---------------------------------------"
            echo "FAILURE: HASH MISMATCH! The file may be corrupted."
            return 1
        fi
    else
        echo "SHA-256: $actual"
        echo "---------------------------------------"
        echo "ACTION: MANUALLY copy this hash into 1Password."
        return 0
    fi
}

encrypt_target() {
    local target=$1
    local output=$2
    local pass=$3

    if [[ -d "$target" ]]; then
        tar -cf - "$target" | $OPENSSL enc -aes-256-cbc -salt -pbkdf2 -pass "pass:$pass" -out "$output"
    else
        $OPENSSL enc -aes-256-cbc -salt -pbkdf2 -pass "pass:$pass" -in "$target" -out "$output"
    fi

    if [[ $? -eq 0 ]]; then
        echo "Encryption complete: $output"
        verify_target "$output" ""
    else
        echo "Error: Encryption failed."
        exit 1
    fi
}

decrypt_target() {
    local target=$1
    local output=$2
    local pass=$3
    local temp_out="$output.tmp"

    if [[ -d "$target" ]]; then
        echo "Error: '$target' is a directory."
        exit 1
    fi

    trap "rm -f $temp_out" EXIT

    ERR_MSG=$($OPENSSL enc -aes-256-cbc -d -salt -pbkdf2 -pass "pass:$pass" -in "$target" -out "$temp_out" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        if [[ "$ERR_MSG" == *"bad decrypt"* ]]; then
            echo "Error: Decryption failed. Incorrect password."
        elif [[ "$ERR_MSG" == *"bad magic number"* ]]; then
            echo "Error: '$target' is not a valid encrypted file."
        else
            echo "Error: $ERR_MSG"
        fi
        exit 1
    fi

    if file "$temp_out" | grep -q "tar archive"; then
        tar -xf "$temp_out" -C ./
        echo "Directory decrypted and extracted."
    else
        mv "$temp_out" "$output"
        echo "File decrypted: $output"
    fi
}

#=======================#
#                       #
#    M A I N L I N E    #
#                       #
#=======================#  

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_command_line "$@"
    validate_target "$TARGET"
    
    CLEAN_TARGET="${TARGET%/}"
    BASE_NAME=$(basename "$CLEAN_TARGET")

    case "$CMD" in
        verify)
            verify_target "$TARGET" "$OPT_HASH"
            ;;
        encrypt)
            PASSWORD=$(get_password "$OPT_PASS")
            [[ -z "$OPT_OUT" ]] && OPT_OUT="./x-$BASE_NAME"
            encrypt_target "$TARGET" "$OPT_OUT" "$PASSWORD"
            ;;
        decrypt)
            # Integrity Check Guard Rail
            if [[ -n "$OPT_HASH" ]]; then
                verify_target "$TARGET" "$OPT_HASH"
                if [[ $? -ne 0 ]]; then
                    echo "Aborting decryption due to integrity failure."
                    exit 1
                fi
            fi

            PASSWORD=$(get_password "$OPT_PASS")
            if [[ -z "$OPT_OUT" ]]; then
                [[ "$BASE_NAME" == x-* ]] && OPT_OUT="${BASE_NAME#x-}" || OPT_OUT="decrypted-$BASE_NAME"
            fi
            decrypt_target "$TARGET" "$OPT_OUT" "$PASSWORD"
            ;;
        *)
            echo "Error: Unknown command '$CMD'"
            usage
            ;;
    esac
fi
