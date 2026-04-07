#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# mycipher.sh — File/Directory Encryption & External SHA-256 Verification Utility
# ------------------------------------------------------------------------------
#
# Usage:
#   mycipher.sh encrypt [-p password] [-o output_file] <file_or_directory>
#   mycipher.sh decrypt [-p password] [-o output_file] [-v expected_hash] <file_or_directory>
#   mycipher.sh verify <file_or_directory> <expected_hash>
#
# Commands:
#   encrypt   Encrypt a file or directory.
#   decrypt   Decrypt an encrypted file. Optionally verify its SHA-256 first.
#   verify    Compute SHA-256 for an encrypted file and compare it with the
#             expected hash you stored separately.
#
# Workflow:
#   1. Encrypt a target file or directory.
#      ╰─❯ mycipher.sh encrypt my-file.pdf     # => x-my-file.pdf
#      ╰─❯ mycipher.sh encrypt my-directory    # => x-my-directory
#
#   2. Manually copy the resulting SHA-256 hash and the encryption password
#      into your 1Password entry for the encrypted file.
#
#   3. Upload the encrypted x-* file to cloud storage.
#
#   4. Periodically verify the encrypted file to detect corruption or bit rot by
#      comparing its current SHA-256 with the hash you saved separately.
#      ╰─❯ mycipher.sh verify x-my-directory <hash-from-1password>
#
#   5. Download an encrypted file and decrypt it. If you provide -v <hash>,
#      the script verifies the encrypted file before decrypting it.
#      ╰─❯ mycipher.sh decrypt -v <hash-from-1password> x-my-directory
#
# Password resolution:
#   1. Uses -p <password> if provided.
#   2. Else reads the first line of ~/.mycipher exactly as stored.
#   3. Else prompts via hidden terminal input.
#
# Implementation notes:
#   - OpenSSL binary: /opt/homebrew/bin/openssl
#   - Cipher: AES-256-CBC with PBKDF2 and a random salt stored in the OpenSSL
#     output format.
#   - Directories are tar-streamed before encryption.
#   - Decryption uses the 'file' utility to heuristically detect whether the
#     plaintext is a tar archive and extracts it if so.
#   - Integrity verification is external: SHA-256 is computed over the encrypted
#     file and compared with a separately stored expected hash.
# ------------------------------------------------------------------------------

set -o pipefail

# --- Global Configuration & State ---

readonly OPENSSL="/opt/homebrew/bin/openssl"
readonly PW_FILE="$HOME/.mycipher"

CMD=""            # encrypt | decrypt | verify
OPT_PASS=""       # Password from -p
OPT_OUT=""        # Output filename from -o
EXPECTED_HASH=""  # Expected hash from -v or verify positional arg
TARGET=""         # Target file or directory
PASSWORD=""       # Resolved password string

# --- Helper Functions ---

usage() {
    printf '%s\n' \
        "Usage:" \
        "  $0 encrypt [-p password] [-o output_file] <file_or_directory>" \
        "  $0 decrypt [-p password] [-o output_file] [-v expected_hash] <file_or_directory>" \
        "  $0 verify <file_or_directory> <expected_hash>"
    exit 1
}

validate_target() {
    local target=$1

    if [[ -z "$target" ]]; then
        printf "Error: No file or directory specified.\n" >&2
        usage
    fi

    if [[ ! -e "$target" ]]; then
        printf "Error: Target '%s' does not exist.\n" "$target" >&2
        exit 1
    fi
}

get_password() {
    local pass_arg=$1
    local file_pass=""
    local manual_pass=""

    if [[ -n "$pass_arg" ]]; then
        printf '%s' "$pass_arg"
    elif [[ -f "$PW_FILE" ]]; then
        IFS= read -r file_pass < "$PW_FILE"
        printf '%s' "$file_pass"
    else
        read -r -s -p "Enter password: " manual_pass
        printf '\n' >&2
        printf '%s' "$manual_pass"
    fi
}

parse_command_line() {
    OPTIND=1

    CMD=${1:-}
    [[ -n "$CMD" ]] || usage
    shift || usage

    case "$CMD" in
        verify)
            TARGET=${1:-}
            EXPECTED_HASH=${2:-}

            [[ -n "$TARGET" ]] || usage
            [[ -n "$EXPECTED_HASH" ]] || {
                printf "Error: verify requires both <file_or_directory> and <expected_hash>.\n" >&2
                usage
            }

            [[ $# -eq 2 ]] || usage
            ;;
        encrypt|decrypt)
            while getopts "p:o:v:" opt; do
                case "$opt" in
                    p) OPT_PASS=$OPTARG ;;
                    o) OPT_OUT=$OPTARG ;;
                    v) EXPECTED_HASH=$OPTARG ;;
                    *) usage ;;
                esac
            done
            shift $((OPTIND - 1))

            TARGET=${1:-}
            ;;
        *)
            usage
            ;;
    esac
}

# --- Core Logic Functions ---

verify_target() {
    local target=$1
    local expected=$2
    local actual=""

    if [[ ! -f "$target" ]]; then
        printf "Error: Cannot verify. '%s' is not a file.\n" "$target" >&2
        return 1
    fi

    actual=$("$OPENSSL" dgst -sha256 "$target" | awk '{print $NF}')

    printf -- "--- Integrity Report for: %s ---\n" "$target"

    if [[ "$actual" == "$expected" ]]; then
        printf '%s\n' \
            "SUCCESS: Integrity confirmed. Hash matches." \
            "---------------------------------------"
        return 0
    fi

    printf '%s\n' \
        "ACTUAL:   $actual" \
        "EXPECTED: $expected" \
        "---------------------------------------" \
        "FAILURE: HASH MISMATCH! The file may be corrupted."
    return 1
}

encrypt_target() {
    local target=$1
    local output=$2
    local pass=$3

    if [[ -d "$target" ]]; then
        tar -cf - "$target" | "$OPENSSL" enc -aes-256-cbc -salt -pbkdf2 -pass "pass:$pass" -out "$output"
    else
        "$OPENSSL" enc -aes-256-cbc -salt -pbkdf2 -pass "pass:$pass" -in "$target" -out "$output"
    fi

    if [[ $? -eq 0 ]]; then
        printf "Encryption complete: %s\n" "$output"
        "$OPENSSL" dgst -sha256 "$output" | awk '{print "SHA-256: " $NF}'
        printf '%s\n' "ACTION: MANUALLY copy this hash into 1Password."
    else
        printf '%s\n' "Error: Encryption failed." >&2
        exit 1
    fi
}

decrypt_target() {
    local target=$1
    local output=$2
    local pass=$3
    local temp_out="${output}.tmp"
    local err_msg=""

    if [[ -d "$target" ]]; then
        printf "Error: '%s' is a directory.\n" "$target" >&2
        exit 1
    fi

    trap 'rm -f -- "$temp_out"' EXIT

    err_msg=$("$OPENSSL" enc -aes-256-cbc -d -salt -pbkdf2 -pass "pass:$pass" -in "$target" -out "$temp_out" 2>&1)

    if [[ $? -ne 0 ]]; then
        if [[ "$err_msg" == *"bad decrypt"* ]]; then
            printf '%s\n' "Error: Decryption failed. Incorrect password." >&2
        elif [[ "$err_msg" == *"bad magic number"* ]]; then
            printf "Error: '%s' is not a valid encrypted file.\n" "$target" >&2
        else
            printf "Error: %s\n" "$err_msg" >&2
        fi
        exit 1
    fi

    if file "$temp_out" | grep -q "tar archive"; then
        tar -xf "$temp_out" -C ./
        rm -f -- "$temp_out"
        printf '%s\n' "Directory decrypted and extracted."
    else
        mv -- "$temp_out" "$output"
        printf "File decrypted: %s\n" "$output"
    fi

    trap - EXIT
}

run_verify() {
    validate_target "$TARGET"
    verify_target "$TARGET" "$EXPECTED_HASH"
}

run_encrypt() {
    local clean_target=""
    local base_name=""

    validate_target "$TARGET"

    clean_target="${TARGET%/}"
    base_name=$(basename "$clean_target")

    PASSWORD=$(get_password "$OPT_PASS")
    [[ -z "$OPT_OUT" ]] && OPT_OUT="./x-$base_name"

    encrypt_target "$TARGET" "$OPT_OUT" "$PASSWORD"
}

run_decrypt() {
    local clean_target=""
    local base_name=""

    validate_target "$TARGET"

    if [[ -n "$EXPECTED_HASH" ]]; then
        verify_target "$TARGET" "$EXPECTED_HASH"
        if [[ $? -ne 0 ]]; then
            printf '%s\n' "Aborting decryption due to integrity failure." >&2
            exit 1
        fi
    fi

    clean_target="${TARGET%/}"
    base_name=$(basename "$clean_target")

    PASSWORD=$(get_password "$OPT_PASS")

    if [[ -z "$OPT_OUT" ]]; then
        if [[ "$base_name" == x-* ]]; then
            OPT_OUT="${base_name#x-}"
        else
            OPT_OUT="decrypted-$base_name"
        fi
    fi

    decrypt_target "$TARGET" "$OPT_OUT" "$PASSWORD"
}

#=======================#
#                       #
#    M A I N L I N E    #
#                       #
#=======================#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_command_line "$@"
    case "$CMD" in
        verify)  run_verify  ;;
        encrypt) run_encrypt ;;
        decrypt) run_decrypt ;;
        *) printf "Error: Unknown command '%s'\n" "$CMD" >&2; usage ;;
    esac
fi

