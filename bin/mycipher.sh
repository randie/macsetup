#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# mycipher.sh — File/Directory Encryption & External SHA-256 Verification Utility
# ------------------------------------------------------------------------------
#
# Usage:
#   mycipher.sh encrypt [-p password] [-o output_file] <file_or_directory>
#   mycipher.sh decrypt [-p password] [-o output_file] [-v expected_hash] <encrypted_file>
#   mycipher.sh verify <encrypted_file> <expected_hash>
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
#      ╰─❯ mycipher.sh encrypt my-directory    # => x-my-directory,dir
#
#   2. Manually copy the resulting SHA-256 hash and the encryption password
#      into your 1Password entry for the encrypted file.
#
#   3. Upload the encrypted x-* file to cloud storage.
#
#   4. Periodically verify the encrypted file to detect corruption or bit rot by
#      comparing its current SHA-256 with the hash you saved separately.
#      ╰─❯ mycipher.sh verify x-my-directory,dir <hash-from-1password>
#
#   5. Download an encrypted file and decrypt it. If you provide -v <hash>,
#      the script verifies the encrypted file before decrypting it.
#      ╰─❯ mycipher.sh decrypt -v <hash-from-1password> x-my-directory,dir
#
# Password resolution:
#   1. Uses -p <password> if provided,
#   2. else reads the first line of ~/.mycipher exactly as stored,
#   3. else prompts via hidden terminal input.
#
# Implementation notes:
#   - OpenSSL binary: /opt/homebrew/bin/openssl
#   - Cipher: AES-256-CBC with PBKDF2 and a random salt stored in the OpenSSL
#     output format.
#   - Directories are tar-streamed before encryption.
#   - Encrypted directories are given the filename suffix ',dir' by default:
#       x-<dirname>,dir
#     This encodes encrypted-directory metadata in the filename so decrypt can
#     distinguish encrypted directories from encrypted files.
#   - The suffix ',dir' is reserved for encrypted-directory filename metadata.
#     Source files whose basename ends in ',dir' are rejected, because their
#     encrypted output would be misclassified as a directory and break decrypt.
#   - Source directories may still end in ',dir'; that can produce names like
#     x-foobar,dir,dir, which is weird-looking but is not logically incorrect.
#   - Custom -o output names for encrypted files must not end in ',dir'.
#   - During decryption, directory detection prefers the ',dir' filename suffix.
#     If the suffix is absent, the script falls back to tar-archive detection
#     for backward compatibility with older encrypted directories.
#   - Integrity verification is external: SHA-256 is computed over the encrypted
#     file and compared with a separately stored expected hash.
# ------------------------------------------------------------------------------

set -o pipefail

# --- Global Configuration & State ---

readonly OPENSSL="/opt/homebrew/bin/openssl"
readonly PW_FILE="$HOME/.mycipher"
readonly PREFIX="x-"
readonly SUFFIX=",dir"

CMD=""            # encrypt | decrypt | verify
OPT_PASS=""       # Password from -p
OPT_OUT=""        # Output filename from -o
EXPECTED_HASH=""  # Expected hash from -v or verify positional arg
TARGET=""         # Target path, normalized to remove any trailing slash
BASE_NAME=""      # Basename derived from TARGET
PASSWORD=""       # Resolved password string

# --- Helper Functions ---

usage() {
    printf '%s\n' \
        "Usage:" \
        "  $0 encrypt [-p password] [-o output_file] <file_or_directory>" \
        "  $0 decrypt [-p password] [-o output_file] [-v expected_hash] <encrypted_file>" \
        "  $0 verify <encrypted_file> <expected_hash>"
    exit 1
}

validate_target() {
    if [[ -z "$TARGET" ]]; then
        printf "Error: No file or directory specified.\n" >&2
        usage
    fi

    [[ "$TARGET" != "/" ]] && TARGET="${TARGET%/}"

    if [[ ! -e "$TARGET" ]]; then
        printf "Error: Target '%s' does not exist.\n" "$TARGET" >&2
        exit 1
    fi
}

prepare_target() {
    validate_target
    BASE_NAME=$(basename "$TARGET")
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
            if [[ ${1:-} == -* || ${2:-} == -* ]]; then
                printf '%s\n' "Error: verify does not accept options. Use: $0 verify <encrypted_file> <expected_hash>" >&2
                usage
            fi

            TARGET=${1:-}
            EXPECTED_HASH=${2:-}

            [[ -n "$TARGET" ]] || usage
            [[ -n "$EXPECTED_HASH" ]] || {
                printf "Error: verify requires both <encrypted_file> and <expected_hash>.\n" >&2
                usage
            }

            [[ $# -eq 2 ]] || usage
            ;;
        encrypt)
            while getopts "p:o:" opt; do
                case "$opt" in
                    p) OPT_PASS=$OPTARG ;;
                    o) OPT_OUT=$OPTARG ;;
                    *) usage ;;
                esac
            done
            shift $((OPTIND - 1))

            [[ $# -eq 1 ]] || usage
            TARGET=$1
            ;;
        decrypt)
            while getopts "p:o:v:" opt; do
                case "$opt" in
                    p) OPT_PASS=$OPTARG ;;
                    o) OPT_OUT=$OPTARG ;;
                    v) EXPECTED_HASH=$OPTARG ;;
                    *) usage ;;
                esac
            done
            shift $((OPTIND - 1))

            [[ $# -eq 1 ]] || usage
            TARGET=$1
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
    local is_directory=1

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

    if [[ "$target" == *"$SUFFIX" ]]; then
        is_directory=0
    elif file "$temp_out" | grep -q "tar archive"; then
        is_directory=0
    fi

    if [[ $is_directory -eq 0 ]]; then
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
    prepare_target
    verify_target "$TARGET" "$EXPECTED_HASH"
}

run_encrypt() {
    prepare_target

    if [[ -f "$TARGET" && "$BASE_NAME" == *"$SUFFIX" ]]; then
        printf "Error: Target filename '%s' must not end with reserved suffix '%s'.\n" "$BASE_NAME" "$SUFFIX" >&2
        exit 1
    fi

    PASSWORD=$(get_password "$OPT_PASS")

    if [[ -n "$OPT_OUT" && ! -d "$TARGET" && "$(basename "$OPT_OUT")" == *"$SUFFIX" ]]; then
        printf "Error: Custom encrypted output name '%s' must not end with reserved suffix '%s' for files.\n" "$(basename "$OPT_OUT")" "$SUFFIX" >&2
        exit 1
    fi

    if [[ -z "$OPT_OUT" ]]; then
        if [[ -d "$TARGET" ]]; then
            OPT_OUT="./${PREFIX}${BASE_NAME}${SUFFIX}"
        else
            OPT_OUT="./${PREFIX}${BASE_NAME}"
        fi
    fi

    encrypt_target "$TARGET" "$OPT_OUT" "$PASSWORD"
}

run_decrypt() {
    prepare_target

    if [[ -n "$EXPECTED_HASH" ]]; then
        verify_target "$TARGET" "$EXPECTED_HASH"
        if [[ $? -ne 0 ]]; then
            printf '%s\n' "Aborting decryption due to integrity failure." >&2
            exit 1
        fi
    fi

    PASSWORD=$(get_password "$OPT_PASS")

    if [[ -z "$OPT_OUT" ]]; then
        if [[ "$BASE_NAME" == "$PREFIX"* ]]; then
            OPT_OUT="${BASE_NAME#"$PREFIX"}"
        else
            OPT_OUT="decrypted-$BASE_NAME"
        fi

        [[ "$OPT_OUT" == *"$SUFFIX" ]] && OPT_OUT="${OPT_OUT%"$SUFFIX"}"
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

