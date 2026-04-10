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
#   3. Upload the encrypted output file to cloud storage.
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
#   • OpenSSL binary: /opt/homebrew/bin/openssl
#   • Cipher: AES-256-CBC with PBKDF2 and a random salt stored in the OpenSSL
#     output format.
#   • Directories are tar-streamed before encryption.
#   • Encrypting '.' is not supported. Move up to the parent directory first
#     and try again.
#   • Encrypting '/' is not supported because it is too large and broad for
#     this utility.
#   • Encrypted directories are given the filename suffix ',dir' by default:
#       x-<dirname>,dir
#     This encodes encrypted-directory metadata in the filename so decrypt can
#     distinguish encrypted directories from encrypted files.
#   • The suffix ',dir' is reserved for encrypted-directory filename metadata.
#     Source files whose basename ends in ',dir' are rejected, because their
#     encrypted output would be misclassified as a directory and break decrypt.
#   • Source directories may still end in ',dir'; that can produce names like
#     x-foobar,dir,dir, which is weird-looking but is not logically incorrect.
#   • Custom -o output names for encrypted files must not end in ',dir'.
#   • During decryption, directory detection prefers the ',dir' filename suffix.
#     If the suffix is absent, the script falls back to tar-archive detection
#     for backward compatibility with older encrypted directories.
#   • Integrity verification is external: SHA-256 is computed over the encrypted
#     file and compared with a separately stored expected hash.
# ------------------------------------------------------------------------------

set -o pipefail

# --- Global Configuration & State ---

readonly OPENSSL="/opt/homebrew/bin/openssl"
readonly PASSWORD_FILE="$HOME/.mycipher"
readonly PREFIX="x-"
readonly SUFFIX=",dir"

CMD=""            # encrypt | decrypt | verify
OPT_PASSWORD=""   # Password from -p
OUTPUT=""         # Final output path from -o or derived default
EXPECTED_HASH=""  # Expected hash from verify arg or decrypt -v
TARGET=""         # Target path, normalized to remove any trailing slash
BASE_NAME=""      # Basename derived from TARGET
PASSWORD=""       # Resolved password string

# --- Helper Functions ---

usage() {
    local script_name="${0##*/}"
    printf '%s\n' \
        "Usage:" \
        "  $script_name encrypt [-p password] [-o output_file] <file_or_directory>" \
        "  $script_name decrypt [-p password] [-o output_file] [-v expected_hash] <encrypted_file>" \
        "  $script_name verify <encrypted_file> <expected_hash>"
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
    BASE_NAME="${TARGET##*/}"
}

get_password() {
    local password_arg=$1
    local file_password=""
    local manual_password=""

    if [[ -n "$password_arg" ]]; then
        printf '%s' "$password_arg"
    elif [[ -f "$PASSWORD_FILE" ]]; then
        IFS= read -r file_password < "$PASSWORD_FILE"
        printf '%s' "$file_password"
    else
        read -r -s -p "Enter password: " manual_password
        printf '\n' >&2
        printf '%s' "$manual_password"
    fi
}

parse_verify_args() {
    local script_name="${0##*/}"

    if [[ ${1:-} == "--" ]]; then
        shift
    elif [[ ${1:-} == -* || ${2:-} == -* ]]; then
        printf '%s\n' "Error: verify does not accept options. Use: $script_name verify <encrypted_file> <expected_hash>" >&2
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
}

parse_encrypt_args() {
    while getopts "p:o:" opt; do
        case "$opt" in
            p) OPT_PASSWORD=$OPTARG ;;
            o) OUTPUT=$OPTARG ;;
            *) usage ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# -eq 1 ]] || usage
    TARGET=$1
}

parse_decrypt_args() {
    while getopts "p:o:v:" opt; do
        case "$opt" in
            p) OPT_PASSWORD=$OPTARG ;;
            o) OUTPUT=$OPTARG ;;
            v) EXPECTED_HASH=$OPTARG ;;
            *) usage ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# -eq 1 ]] || usage
    TARGET=$1
}

parse_command_line() {
    OPTIND=1

    CMD=${1:-}
    [[ -n "$CMD" ]] || usage
    shift || usage

    case "$CMD" in
        verify)  parse_verify_args "$@"  ;;
        encrypt) parse_encrypt_args "$@" ;;
        decrypt) parse_decrypt_args "$@" ;;
        *) usage ;;
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

    if [[ "$actual" != "$expected" ]]; then
        printf '%s\n' \
            "FAILURE:       SHA-256 hash does not match. Integrity compromised." \
            "ACTUAL HASH:   $actual" \
            "EXPECTED HASH: $expected"
        return 1
    fi

    printf '%s\n' \
        "SUCCESS: SHA-256 hash matches. Integrity confirmed."
}

encrypt_target() {
    local target=$1
    local output=$2
    local password=$3
    local target_parent=""
    local target_name=""

    if [[ -e "$output" ]]; then
        printf "Error: Output path '%s' already exists.\n" "$output" >&2
        exit 1
    fi

    if [[ -d "$target" ]]; then
        target_name="${target##*/}"
        if [[ "$target" == */* ]]; then
            target_parent="${target%/*}"
            [[ -z "$target_parent" ]] && target_parent="/"
        else
            target_parent="."
        fi

        if ! tar -C "$target_parent" -cf - "$target_name" | "$OPENSSL" enc -aes-256-cbc -salt -pbkdf2 -pass "pass:$password" -out "$output"; then
            printf '%s\n' "Error: Encryption failed." >&2
            exit 1
        fi
    else
        if ! "$OPENSSL" enc -aes-256-cbc -salt -pbkdf2 -pass "pass:$password" -in "$target" -out "$output"; then
            printf '%s\n' "Error: Encryption failed." >&2
            exit 1
        fi
    fi

    printf "Encryption complete: %s → %s\n" "$target" "$output"
    printf '%s\n' "PASSWORD: from -p <password> | ~/.mycipher | prompt (in this precedence order)"
    "$OPENSSL" dgst -sha256 "$output" | awk '{print "SHA-256: " $NF}'
    printf "TO DO: Copy password and SHA-256 hash to 1Password for %s\n" "$output"
}

decrypt_target() {
    local target=$1
    local output=$2
    local password=$3
    local temp_output="${output}.tmp"
    local temp_extract_dir=""
    local extracted_entries=()
    local extracted_path=""
    local error_message=""
    local was_directory=false    # Was this encrypted file a directory?

    if [[ -d "$target" ]]; then
        printf "Error: '%s' is a directory, not a valid encrypted file.\n" "$target" >&2
        exit 1
    fi

    if [[ -e "$output" ]]; then
        printf "Error: Output path '%s' already exists.\n" "$output" >&2
        exit 1
    fi

    if [[ -e "$temp_output" ]]; then
        printf "Error: Temporary output path '%s' already exists.\n" "$temp_output" >&2
        exit 1
    fi

    if ! temp_extract_dir=$(mktemp -d); then
        printf '%s\n' "Error: Failed to create temporary extraction directory." >&2
        exit 1
    fi

    trap 'rm -f -- "$temp_output"; rm -rf -- "$temp_extract_dir"' EXIT

    if ! error_message=$("$OPENSSL" enc -aes-256-cbc -d -salt -pbkdf2 -pass "pass:$password" -in "$target" -out "$temp_output" 2>&1); then
        if [[ "$error_message" == *"bad decrypt"* ]]; then
            printf '%s\n' "Error: Decryption failed. Incorrect password." >&2
        elif [[ "$error_message" == *"bad magic number"* ]]; then
            printf "Error: '%s' is not a valid encrypted file.\n" "$target" >&2
        else
            printf "Error: %s\n" "$error_message" >&2
        fi
        exit 1
    fi

    if [[ "$target" == *"$SUFFIX" ]] || file "$temp_output" | grep -q "tar archive"; then
        was_directory=true
    fi

    if [[ "$was_directory" == true ]]; then
        if ! tar -xf "$temp_output" -C "$temp_extract_dir"; then
            printf "Error: Failed to extract decrypted directory from '%s'.\n" "$target" >&2
            exit 1
        fi

        mapfile -d '' -t extracted_entries < <(find "$temp_extract_dir" -mindepth 1 -maxdepth 1 -print0)

        if [[ ${#extracted_entries[@]} -eq 0 ]]; then
            printf "Error: Decrypted directory archive '%s' was empty.\n" "$target" >&2
            exit 1
        fi

        if [[ ${#extracted_entries[@]} -ne 1 ]]; then
            printf "Error: Decrypted directory archive '%s' contained multiple top-level entries.\n" "$target" >&2
            exit 1
        fi

        extracted_path="${extracted_entries[0]}"

        if ! mv -- "$extracted_path" "$output"; then
            printf "Error: Failed to move decrypted directory to '%s'.\n" "$output" >&2
            exit 1
        fi

        rm -f -- "$temp_output"
    else
        if ! mv -- "$temp_output" "$output"; then
            printf "Error: Failed to write decrypted file to '%s'.\n" "$output" >&2
            exit 1
        fi
    fi

    printf "Decryption complete: %s → %s\n" "$target" "$output"

    trap - EXIT
    rm -rf -- "$temp_extract_dir"
}

run_verify() {
    prepare_target
    verify_target "$TARGET" "$EXPECTED_HASH"
}

run_encrypt() {
    local target_dir_abs=""
    local output_dir_abs=""
    local output_path_abs=""

    prepare_target

    if [[ "$TARGET" == "." ]]; then
        printf '%s\n' "Error: Encrypting '.' is not supported. Move up to the parent directory first and try again." >&2
        exit 1
    fi

    if [[ "$TARGET" == "/" ]]; then
        printf '%s\n' "Error: Encrypting '/' is not supported because it is too large and broad for this utility." >&2
        exit 1
    fi

    if [[ -f "$TARGET" && "$BASE_NAME" == *"$SUFFIX" ]]; then
        printf "Error: Target filename '%s' must not end with reserved suffix '%s'.\n" "$BASE_NAME" "$SUFFIX" >&2
        exit 1
    fi

    PASSWORD=$(get_password "$OPT_PASSWORD")

    if [[ -n "$OUTPUT" && ! -d "$TARGET" && "${OUTPUT##*/}" == *"$SUFFIX" ]]; then
        printf "Error: Custom encrypted output name '%s' must not end with reserved suffix '%s' for files.\n" "${OUTPUT##*/}" "$SUFFIX" >&2
        exit 1
    fi

    if [[ -z "$OUTPUT" ]]; then
        if [[ -d "$TARGET" ]]; then
            OUTPUT="./${PREFIX}${BASE_NAME}${SUFFIX}"
        else
            OUTPUT="./${PREFIX}${BASE_NAME}"
        fi
    fi

    if [[ -d "$TARGET" ]]; then
        if ! target_dir_abs=$(cd -- "$TARGET" && pwd -P); then
            printf "Error: Failed to resolve target directory '%s'.\n" "$TARGET" >&2
            exit 1
        fi

        if ! output_dir_abs=$(cd -- "${OUTPUT%/*}" 2>/dev/null && pwd -P); then
            printf "Error: Output directory '%s' does not exist.\n" "${OUTPUT%/*}" >&2
            exit 1
        fi

        output_path_abs="${output_dir_abs}/${OUTPUT##*/}"

        case "$output_path_abs" in
            "$target_dir_abs"/*)
                printf "Error: Output path '%s' must not be inside target directory '%s'.\n" "$OUTPUT" "$TARGET" >&2
                exit 1
                ;;
        esac
    fi

    encrypt_target "$TARGET" "$OUTPUT" "$PASSWORD"
}

run_decrypt() {
    prepare_target

    if [[ -n "$EXPECTED_HASH" ]]; then
        if ! verify_target "$TARGET" "$EXPECTED_HASH"; then
            printf '%s\n' "Aborting decryption due to integrity failure." >&2
            exit 1
        fi
    fi

    PASSWORD=$(get_password "$OPT_PASSWORD")

    if [[ -z "$OUTPUT" ]]; then
        if [[ "$BASE_NAME" == "$PREFIX"* ]]; then
            OUTPUT="${BASE_NAME#"$PREFIX"}"
        else
            OUTPUT="decrypted-$BASE_NAME"
        fi

        [[ "$OUTPUT" == *"$SUFFIX" ]] && OUTPUT="${OUTPUT%"$SUFFIX"}"
    fi

    decrypt_target "$TARGET" "$OUTPUT" "$PASSWORD"
}

#=======================#
#                       #
#    M A I N L I N E    #
#                       #
#=======================#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_command_line "$@"
    case "$CMD" in
        encrypt) run_encrypt ;;
        decrypt) run_decrypt ;;
        verify)  run_verify  ;;
        *) printf "Error: Unknown command '%s'\n" "$CMD" >&2; usage ;;
    esac
fi

