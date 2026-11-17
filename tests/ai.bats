#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    chmod -R u+w "$HOME" 2>/dev/null || true
    teardown_env
}

# Print the 64-digit digest made of number $1.
digest() { printf '%064d' "$1"; }

# Write Ollama manifest $2 (path under manifests/) into store $1, its weights
# layer digest number $3 of $4 bytes (none when $3 is "-"), config digest
# number $5. The weights blob is created with access time $6 ("" for now).
manifest() {
    local store="$1" path="$2" layer="$3" bytes="$4" config="$5" atime="${6:-}"
    mkdir -p "$store/manifests/${path%/*}" "$store/blobs"
    local layers=""
    if [ "$layer" != - ]; then
        layers="{\"mediaType\":\"application/vnd.ollama.image.model\",\"digest\":\"sha256:$(digest "$layer")\",\"size\":$bytes},"
        head -c 2048 /dev/zero >"$store/blobs/sha256-$(digest "$layer")"
        [ -z "$atime" ] || touch -a -d "$atime" "$store/blobs/sha256-$(digest "$layer")"
    fi
    touch "$store/blobs/sha256-$(digest "$config")" "$store/blobs/sha256-$(digest 9)"
    printf '{"schemaVersion":2,"config":{"digest":"sha256:%s","size":4},"layers":[%s{"mediaType":"application/vnd.ollama.image.template","digest":"sha256:%s","size":9}]}' \
        "$(digest "$config")" "$layers" "$(digest 9)" >"$store/manifests/$path"
}

@test "clean_ai: no Ollama store and no Hugging Face cache prints nothing" {
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=(); clean_ai; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0" ]
}

@test "clean_ai: lists only models unused for AI_UNUSED_DAYS, biggest first, and removes the picked one's own blobs" {
    local s="$HOME/.ollama/models"
    manifest "$s" registry.ollama.ai/library/old/7b 1 5242880 7 '200 days ago'
    manifest "$s" hf.co/user/big/Q4 2 10485760 7 '40 days ago'
    manifest "$s" registry.ollama.ai/library/fresh/1b 3 1048576 7 ''
    manifest "$s" registry.ollama.ai/library/nolayer/x - 0 8
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=(); DRY_RUN=1; ui_ask() { echo "ASK $1"; UI_ANSWER=2; return 0; }; clean_ai'
    [ "$status" -eq 0 ]
    [[ "$output" == *"AI models"* ]]
    [[ "$output" == *"2 Ollama models not used for 30 days or more"* ]]
    [[ "$output" == *" 1  hf.co/user/big:Q4"*"10M  last used 40 days ago"*" 2  old:7b"*"5M  last used 200 days ago"* ]]
    [[ "$output" != *"fresh"* ]]
    [[ "$output" != *"nolayer"* ]]
    [[ "$output" == *"ASK Remove which?"* ]]
    [[ "$output" == *"[dry-run] rm -f -- $s/manifests/registry.ollama.ai/library/old/7b $s/blobs/sha256-$(digest 1)"* ]]
    [[ "$output" != *"sha256-$(digest 7)"* ]]
    [[ "$output" != *"sha256-$(digest 9)"* ]]
}

@test "clean_ai: a picked model is deleted for real, the shared blobs stay" {
    local s="$HOME/.ollama/models"
    manifest "$s" registry.ollama.ai/library/old/7b 1 5242880 7 '200 days ago'
    manifest "$s" registry.ollama.ai/library/fresh/1b 3 1048576 7 ''
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=(); ui_ask() { UI_ANSWER=a; return 0; }; clean_ai'
    [ "$status" -eq 0 ]
    [ ! -e "$s/manifests/registry.ollama.ai/library/old/7b" ]
    [ ! -e "$s/blobs/sha256-$(digest 1)" ]
    [ -e "$s/blobs/sha256-$(digest 7)" ]
    [ -e "$s/blobs/sha256-$(digest 9)" ]
    [ -e "$s/manifests/registry.ollama.ai/library/fresh/1b" ]
}

@test "clean_ai: a running server removes through ollama rm, asked once" {
    manifest "$HOME/.ollama/models" registry.ollama.ai/library/a/1 1 2048 7 '200 days ago'
    manifest "$HOME/.ollama/models" registry.ollama.ai/library/b/1 2 2048 7 '200 days ago'
    stub ollama 'echo "ollama $*" >>"$HOME/ollama.calls"'
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=(); DRY_RUN=1; ui_ask() { UI_ANSWER=a; return 0; }; clean_ai'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] ollama rm a:1"* ]]
    [[ "$output" == *"[dry-run] ollama rm b:1"* ]]
    [ "$(cat "$HOME/ollama.calls")" = "ollama list" ]
}

@test "clean_ai: a store the user cannot write goes through sudo" {
    local s="$HOME/sys/models"
    manifest "$s" registry.ollama.ai/library/old/7b 1 2048 7 '200 days ago'
    head -c 4096 /dev/zero >"$s/blobs/sha256-$(digest 5)-partial"
    touch -d '3 days ago' "$s/blobs/sha256-$(digest 5)-partial"
    chmod a-w "$s/blobs" "$s/manifests/registry.ollama.ai/library/old"
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=("$HOME/sys/models"); DRY_RUN=1; ui_confirm() { echo "ASK $1 $3"; return 0; }
                 ui_ask() { UI_ANSWER=1; return 0; }; clean_ai'
    [ "$status" -eq 0 ]
    [[ "$output" == *"ASK Delete unfinished Ollama downloads? (1 files, 4K)"* ]]
    [[ "$output" == *"[dry-run] sudo rm -f -- $s/blobs/sha256-$(digest 5)-partial"* ]]
    [[ "$output" == *"[dry-run] sudo rm -f -- $s/manifests/registry.ollama.ai/library/old/7b"* ]]
}

@test "clean_ai: a download touched today is left to its pull" {
    local s="$HOME/.ollama/models"
    manifest "$s" registry.ollama.ai/library/fresh/1b 3 2048 7 ''
    touch "$s/blobs/sha256-$(digest 5)-partial"
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=(); clean_ai'
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to clean"* ]]
    [ -e "$s/blobs/sha256-$(digest 5)-partial" ]
}

@test "clean_ai: models are kept under -y, unfinished downloads are not" {
    local s="$HOME/.ollama/models"
    manifest "$s" registry.ollama.ai/library/old/7b 1 2048 7 '200 days ago'
    touch -d '3 days ago' "$s/blobs/sha256-$(digest 5)-partial"
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=(); ARG_YES=1; ui_confirm() { return 0; }; clean_ai'
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 unused Ollama models kept under -y: they are downloaded again on next use"* ]]
    [ -e "$s/manifests/registry.ollama.ai/library/old/7b" ]
    [ ! -e "$s/blobs/sha256-$(digest 5)-partial" ]
}

@test "clean_ai: an empty answer removes nothing, AI_UNUSED_DAYS moves the bar" {
    manifest "$HOME/.ollama/models" registry.ollama.ai/library/old/7b 1 2048 7 '10 days ago'
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=(); ui_ask() { UI_ANSWER=""; return 1; }; clean_ai
                 AI_UNUSED_DAYS=5; clean_ai'
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to clean"*"old:7b"*"skipped"* ]]
    [ -e "$HOME/.ollama/models/manifests/registry.ollama.ai/library/old/7b" ]
}

@test "clean_ai: OLLAMA_MODELS naming the same store as a link lists it once, DEEP_CLEAN_SKIP=ollama hides it" {
    manifest "$HOME/real" registry.ollama.ai/library/old/7b 1 2048 7 '200 days ago'
    mkdir -p "$HOME/.ollama"
    ln -s "$HOME/real" "$HOME/.ollama/models"
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=("$HOME/none"); OLLAMA_MODELS=$HOME/real; DRY_RUN=1
                 ui_ask() { UI_ANSWER=n; return 0; }; clean_ai; echo @@; DEEP_CLEAN_SKIP=ollama; clean_ai'
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 Ollama models not used"*"@@"* ]]
    [[ "${output#*@@}" != *"old:7b"* ]]
    [[ "${output#*@@}" == *"nothing to clean"* ]]
}

@test "clean_ai: Hugging Face repos unused for AI_UNUSED_DAYS are offered and removed, recent ones kept" {
    local hub="$HOME/.cache/huggingface/hub"
    mkdir -p "$hub/models--org--old/blobs" "$hub/datasets--org--set/blobs" "$hub/models--org--new/blobs" "$hub/models--org--empty"
    head -c 4096 /dev/zero >"$hub/models--org--old/blobs/a"
    touch -a -d '100 days ago' "$hub/models--org--old/blobs/a"
    touch -a -d '60 days ago' "$hub/datasets--org--set/blobs/b"
    touch "$hub/models--org--new/blobs/c"
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=(); ui_ask() { UI_ANSWER=1-2; return 0; }; clean_ai'
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 Hugging Face models not used for 30 days or more"* ]]
    [[ "$output" == *"org/old"*"last used 100 days ago"* ]]
    [[ "$output" == *"dataset org/set"*"last used 60 days ago"* ]]
    [ ! -e "$hub/models--org--old" ]
    [ ! -e "$hub/datasets--org--set" ]
    [ -d "$hub/models--org--new" ]
    [ -d "$hub/models--org--empty" ]
}

@test "clean_ai: HF_HUB_CACHE moves the hub, DEEP_CLEAN_SKIP=huggingface hides it" {
    mkdir -p "$HOME/hub/models--org--old/blobs"
    touch -a -d '100 days ago' "$HOME/hub/models--org--old/blobs/a"
    run sys_lib '_AI_OLLAMA_SYSTEM_DIRS=(); HF_HUB_CACHE=$HOME/hub; ui_ask() { UI_ANSWER=n; return 0; }; clean_ai
                 echo @@; DEEP_CLEAN_SKIP=huggingface; clean_ai'
    [ "$status" -eq 0 ]
    [[ "${output%@@*}" == *"org/old"* ]]
    [[ "${output#*@@}" == *"nothing to clean"* ]]
}

@test "_ai_ollama_name: default library drops the registry, others keep host and namespace" {
    run sys_lib '_ai_ollama_name registry.ollama.ai/library/qwen3/30b; echo; _ai_ollama_name hf.co/user/model/Q4_K_M'
    [ "$status" -eq 0 ]
    [ "$output" = $'qwen3:30b\nhf.co/user/model:Q4_K_M' ]
}
