#!/usr/bin/env bash
# Deep clean, AI models section: local models not used for AI_UNUSED_DAYS
# days (Ollama, Hugging Face hub cache) and Ollama downloads left unfinished.
# Last use is the access time of a model's weights, so a backup or indexer
# reading them counts as a use. Models are never offered under -y.

: "${AI_UNUSED_DAYS:=30}"

# Ollama model stores of a system-wide install (Linux service, Arch package),
# checked after $OLLAMA_MODELS and ~/.ollama/models.
_AI_OLLAMA_SYSTEM_DIRS=(/usr/share/ollama/.ollama/models /var/lib/ollama/.ollama/models /var/lib/ollama)

# Offer the unused models of every Ollama store and Hugging Face hub cache
# found, and each store's unfinished downloads, then add the growth of free
# space on / to SUMMARY_FREED_KB. Silent when no store exists.
clean_ai() {
    # The menu arrays are read and filled by _deep_menu_read and _deep_menu.
    # shellcheck disable=SC2034
    local -a stores=() menu_names=() menu_kb=() menu_notes=() menu_refs=()
    local hub store free_before
    mapfile -t stores < <(_ai_ollama_stores)
    hub=$(_ai_hf_hub)
    (( ${#stores[@]} > 0 )) || [[ -n $hub ]] || return 0
    ui_title "AI models"
    _DEEP_TASK_COUNT=0
    free_before=$(sys_free_space k /)
    _AI_OLLAMA_UP=""

    for store in ${stores[@]+"${stores[@]}"}; do _ai_ollama_partial "$store"; done
    if ! _deep_is_skipped ollama; then
        _deep_menu_read < <(for store in ${stores[@]+"${stores[@]}"}; do _ai_ollama_rows "$store"; done)
        _ai_offer ollama "Ollama models" _ai_ollama_remove
    fi
    # shellcheck disable=SC2034
    menu_names=() menu_kb=() menu_notes=() menu_refs=()
    if [[ -n $hub ]] && ! _deep_is_skipped huggingface; then
        _deep_menu_read < <(_ai_hf_rows "$hub")
        _ai_offer huggingface "Hugging Face models" _ai_hf_remove
    fi

    if (( _DEEP_TASK_COUNT == 0 )); then
        ui_ok "nothing to clean"
        return 0
    fi
    _deep_report_freed "$free_before"
    return 0
}

# Offer clean_ai's menu rows of kind $2 under DEEP_CLEAN_SKIP key $1,
# removed through function $3.
_ai_offer() {
    local key="$1" kind="$2" remover="$3"
    (( ${#menu_names[@]} > 0 )) || return 0
    ui_sub "${#menu_names[@]} $kind not used for $AI_UNUSED_DAYS days or more"
    _deep_menu "$key" "Remove which?" \
        "${#menu_names[@]} unused $kind kept under -y: they are downloaded again on next use" "$remover"
}

# Print each Ollama model store once, real path, in search order: the
# directories holding a manifests directory.
_ai_ollama_stores() {
    local dir real
    local -A seen=()
    for dir in "${OLLAMA_MODELS:-}" "$HOME/.ollama/models" "${_AI_OLLAMA_SYSTEM_DIRS[@]}"; do
        [[ -n $dir && -d $dir/manifests ]] || continue
        real=$(cd -P -- "$dir" 2>/dev/null && pwd) || continue
        [[ -n ${seen[$real]:-} ]] && continue
        seen[$real]=1
        printf '%s\n' "$real"
    done
}

# Print the Hugging Face hub cache directory ($HF_HUB_CACHE, else
# $HF_HOME/hub, else ~/.cache/huggingface/hub), empty when it does not exist.
_ai_hf_hub() {
    local hub="${HF_HUB_CACHE:-${HF_HOME:-$HOME/.cache/huggingface}/hub}"
    [[ -d $hub ]] && printf '%s\n' "$hub"
    return 0
}

# Print the digests ("sha256-<hex>", the blob file names) manifest $1 lists.
_ai_manifest_digests() {
    { grep -o 'sha256:[0-9a-f]\{64\}' -- "$1" 2>/dev/null || true; } | sed 's/:/-/' | sort -u
}

# Print a menu row "KiB<TAB>name<TAB>note<TAB>store|manifest" for each model
# of Ollama store $1 whose weights were last read AI_UNUSED_DAYS days ago or
# more. A manifest without a weights layer is left out.
_ai_ollama_rows() {
    local store="$1" manifest name layer digest bytes blob days
    while IFS= read -r manifest; do
        layer=$({ grep -o '{[^{}]*vnd\.ollama\.image\.model"[^{}]*}' -- "$manifest" 2>/dev/null || true; } | head -n 1)
        [[ $layer =~ sha256:([0-9a-f]{64}) ]] || continue
        digest="sha256-${BASH_REMATCH[1]}"
        [[ $layer =~ \"size\":([0-9]+) ]] && bytes=${BASH_REMATCH[1]} || bytes=0
        blob="$store/blobs/$digest"
        [[ -f $blob ]] || continue
        days=$(_deep_days_since "$(_deep_atime "$blob")")
        (( days >= AI_UNUSED_DAYS )) || continue
        name=$(_ai_ollama_name "${manifest#"$store/manifests/"}")
        printf '%s\t%s\t%s\t%s\n' $(( bytes / 1024 )) "$name" "last used $days days ago" "$store|$manifest"
    done < <(find "$store/manifests" -type f 2>/dev/null | sort)
}

# Print the name `ollama list` shows for manifest path $1 (relative to the
# manifests directory): "model:tag" for the default registry and library,
# "host/namespace/model:tag" otherwise.
_ai_ollama_name() {
    local path="$1" tag model
    tag=${path##*/}
    model=${path%/*}
    model=${model#registry.ollama.ai/library/}
    printf '%s:%s' "$model" "$tag"
}

# Return 0 when the Ollama server answers, asking it once per clean_ai.
_ai_ollama_up() {
    if [[ -z $_AI_OLLAMA_UP ]]; then
        _AI_OLLAMA_UP=0
        sys_has ollama && ollama list >/dev/null 2>&1 && _AI_OLLAMA_UP=1
    fi
    (( _AI_OLLAMA_UP ))
}

# Remove the Ollama model of menu ref $1 ("store|manifest") named $2: through
# `ollama rm` when the server answers, else by deleting its manifest and the
# blobs no other manifest of the store lists (through sudo when the store is
# not writable), as `ollama rm` does.
_ai_ollama_remove() {
    local store="${1%%|*}" manifest="${1#*|}" name="$2" digest
    if _ai_ollama_up; then
        run_cmd "Remove $name" ollama rm "$name" || true
        return 0
    fi
    local -A others=()
    local other
    while IFS= read -r other; do
        [[ $other == "$manifest" ]] && continue
        while IFS= read -r digest; do others[$digest]=1; done < <(_ai_manifest_digests "$other")
    done < <(find "$store/manifests" -type f 2>/dev/null)
    local -a files=("$manifest")
    while IFS= read -r digest; do
        [[ -n ${others[$digest]:-} || ! -e $store/blobs/$digest ]] || files+=("$store/blobs/$digest")
    done < <(_ai_manifest_digests "$manifest")
    local -a prefix=()
    [[ -w ${manifest%/*} && -w $store/blobs ]] || read -r -a prefix <<<"$(sys_sudo_prefix)"
    run_cmd "Remove $name" ${prefix[@]+"${prefix[@]}"} rm -f -- "${files[@]}" || true
    return 0
}

# Offer to delete the unfinished downloads ("-partial" blobs) Ollama store
# $1 holds, untouched for a day so a running pull keeps its own.
_ai_ollama_partial() {
    local store="$1" count kb=0 file
    local -a parts=()
    mapfile -t parts < <(find "$store/blobs" -maxdepth 1 -type f -name 'sha256-*-partial*' -mtime +0 2>/dev/null)
    count=${#parts[@]}
    (( count > 0 )) || return 0
    for file in "${parts[@]}"; do kb=$(( kb + $(_clean_size_kb "$file") )); done
    local -a prefix=()
    [[ -w $store/blobs ]] || read -r -a prefix <<<"$(sys_sudo_prefix)"
    _deep_task ollama "Delete unfinished Ollama downloads" "($count files, $(_clean_format_kb "$kb"))" \
        ${prefix[@]+"${prefix[@]}"} rm -f -- "${parts[@]}"
}

# Print a menu row "KiB<TAB>name<TAB>note<TAB>dir" for each model or dataset
# of Hugging Face hub cache $1 whose newest blob was last read
# AI_UNUSED_DAYS days ago or more.
_ai_hf_rows() {
    local hub="$1" repo base name blob newest atime days
    for repo in "$hub"/models--* "$hub"/datasets--*; do
        [[ -d $repo ]] || continue
        newest=0
        for blob in "$repo"/blobs/*; do
            [[ -f $blob ]] || continue
            atime=$(_deep_atime "$blob")
            (( atime > newest )) && newest=$atime
        done
        (( newest > 0 )) || continue
        days=$(_deep_days_since "$newest")
        (( days >= AI_UNUSED_DAYS )) || continue
        base=${repo##*/}
        name=${base#*--}
        name=${name//--//}
        [[ $base == datasets--* ]] && name="dataset $name"
        printf '%s\t%s\t%s\t%s\n' "$(_clean_size_kb "$repo")" "$name" "last used $days days ago" "$repo"
    done
}

# Remove the Hugging Face cache directory of menu ref $1, named $2.
_ai_hf_remove() {
    run_cmd "Remove $2" rm -rf -- "$1" || true
    return 0
}
