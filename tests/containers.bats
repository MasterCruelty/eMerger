#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

# Stub docker: local contexts $1 (space separated, "" for a failing context
# ls), info answering only for the contexts in $2, system df printing $3,
# remote ssh:// contexts $4, every other call logged to $HOME/docker.calls.
docker_stub() {
    stub docker "
ctx=''; [ \"\$1\" = --context ] && { ctx=\$2; shift 2; }
case \"\$1\" in
    context) [ -n '$1' ] || exit 1
             for c in $1; do echo \"\$c|unix:///run/\$c.sock\"; done
             for c in ${4:-}; do echo \"\$c|ssh://user@\$c\"; done ;;
    info) case ' $2 ' in *\" \$ctx \"*) exit 0 ;; *) exit 1 ;; esac ;;
    system) printf '$3' ;;
    *) echo \"docker \${ctx:+--context \$ctx }\$*\" >>\"\$HOME/docker.calls\" ;;
esac"
}

@test "clean_containers: without docker or podman prints nothing" {
    run sys_lib 'clean_containers; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0" ]
}

@test "clean_containers: DEEP_CLEAN_SKIP naming both engines prints nothing and probes neither" {
    docker_stub default default ''
    stub podman 'echo "podman $*" >>"$HOME/podman.calls"'
    run sys_lib 'DEEP_CLEAN_SKIP="docker,podman"; clean_containers; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0" ]
    [ ! -e "$HOME/podman.calls" ]
}

@test "clean_containers: dry-run offers each kind per reachable context, keeps stopped containers and volumes under -y" {
    docker_stub "default desktop-linux" default 'Images|4.978GB (8%%)\nContainers|2.188GB (99%%)\nLocal Volumes|1.407GB (16%%)\nBuild Cache|41.92GB\n'
    run sys_lib 'DRY_RUN=1; ARG_YES=1; clean_containers; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Containers"* ]]
    [[ "$output" == *"docker stopped containers kept under -y: they hold files"* ]]
    [[ "$output" != *"container prune"* ]]
    [[ "$output" == *"[dry-run] docker --context default image prune -af"* ]]
    [[ "$output" == *"[dry-run] docker --context default builder prune -af"* ]]
    [[ "$output" == *"docker unused volumes kept under -y: they hold data"* ]]
    [[ "$output" != *"volume prune"* ]]
    [[ "$output" == *"docker (desktop-linux): daemon not running, skipped"* ]]
    [[ "$output" == *"rc=0"* ]]
    [ ! -e "$HOME/docker.calls" ]
}

@test "clean_containers: asks for each kind with its reclaimable size, volumes included without -y" {
    docker_stub default default 'Images|4.978GB (8%%)\nContainers|2.188GB (99%%)\nLocal Volumes|1.407GB (16%%)\nBuild Cache|41.92GB\n'
    run sys_lib 'ui_confirm() { echo "ASK $1 $3"; return 1; }; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"ASK Remove stopped docker containers (their files are lost)? (reclaimable: 2.188GB)"* ]]
    [[ "$output" == *"ASK Remove unused docker images? (reclaimable: 4.978GB)"* ]]
    [[ "$output" == *"ASK Clear docker build cache? (reclaimable: 41.92GB)"* ]]
    [[ "$output" == *"ASK Remove unused docker volumes (their data is lost)? (reclaimable: 1.407GB)"* ]]
    [ ! -e "$HOME/docker.calls" ]
}

@test "clean_containers: a kind reclaiming 0B is not offered, an unknown size shows ?" {
    docker_stub default default 'Images|0B (0%%)\nContainers|0B\nLocal Volumes|0B\n'
    run sys_lib 'ui_confirm() { echo "ASK $1 $3"; return 1; }; clean_containers
                 ARG_YES=1; DRY_RUN=1; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" != *"containers?"* ]]
    [[ "$output" != *"images?"* ]]
    [[ "$output" != *"volumes"* ]]
    [[ "$output" == *"ASK Clear docker build cache? (reclaimable: ?)"* ]]
}

@test "clean_containers: -y runs the prunes and adds the space freed on / to the summary" {
    docker_stub default default 'Images|1GB\nContainers|0B\nLocal Volumes|0B\nBuild Cache|2GB\n'
    stub df 'n=$(cat "$HOME/df.n" 2>/dev/null || echo 0); n=$((n + 1)); echo $n >"$HOME/df.n"
             echo "Filesystem 1024-blocks Used Available Capacity Mounted"; echo "/dev/x 100 0 $((n * 1024)) 0% /"'
    run sys_lib 'ARG_YES=1; clean_containers; echo "freed=$SUMMARY_FREED_KB"'
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/docker.calls")" = "docker --context default image prune -af
docker --context default builder prune -af" ]
    [[ "$output" == *"freed 1M on /"* ]]
    [[ "$output" == *"freed=1024"* ]]
}

@test "clean_containers: daemon reachable only through sudo runs every call through sudo" {
    stub sudo '[ "$1" = -n ] && shift; SUDO_OK=1 exec "$@"'
    stub docker '
[ "$1" = context ] && { echo "default|unix:///var/run/docker.sock"; exit 0; }
[ -n "$SUDO_OK" ] || exit 1
case "$*" in *info*) exit 0 ;; *"system df"*) printf "Build Cache|3GB\n" ;; *) echo "sudo docker $*" >>"$HOME/docker.calls" ;; esac'
    run sys_lib 'sys_is_root() { return 1; }; ui_confirm() { echo "ASK $1 $3"; return 0; }; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"ASK Clear docker build cache? (reclaimable: 3GB)"* ]]
    grep -qx 'sudo docker --context default builder prune -af' "$HOME/docker.calls"
    grep -qx 'sudo docker --context default container prune -f' "$HOME/docker.calls"
}

@test "clean_containers: dry-run never calls sudo for the docker probe" {
    stub docker 'exit 1'
    stub sudo 'echo "$*" >>"$HOME/sudo.calls"; exit 0'
    run sys_lib 'sys_is_root() { return 1; }; DRY_RUN=1; ARG_YES=1; clean_containers; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] sudo docker image prune -af"* ]]
    [[ "$output" == *"rc=0"* ]]
    [ ! -e "$HOME/sudo.calls" ]
}

@test "clean_containers: unreachable daemon without sudo is reported, nothing to clean" {
    docker_stub default '' ''
    stub sudo 'exit 1'
    run sys_lib 'sys_is_root() { return 1; }; ARG_YES=1; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"docker: daemon not reachable (not in the docker group?), skipped"* ]]
    [[ "$output" == *"nothing to clean"* ]]
}

@test "clean_containers: as root an unreachable daemon is skipped without sudo" {
    docker_stub default '' ''
    stub sudo 'echo "$*" >>"$HOME/sudo.calls"; exit 0'
    run sys_lib 'sys_is_root() { return 0; }; ARG_YES=1; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"daemon not reachable"* ]]
    [ ! -e "$HOME/sudo.calls" ]
}

@test "clean_containers: failing context ls targets docker without --context" {
    stub docker 'case "$1" in context) exit 1 ;; info) exit 0 ;; system) printf "Images|5MB\n" ;; *) echo "docker $*" >>"$HOME/docker.calls" ;; esac'
    run sys_lib 'ARG_YES=1; clean_containers'
    [ "$status" -eq 0 ]
    grep -qx 'docker image prune -af' "$HOME/docker.calls"
}

@test "clean_containers: a remote context is never probed or pruned" {
    docker_stub default "default prod" 'Images|1GB\n' prod
    run sys_lib 'ARG_YES=1; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"docker (prod): remote engine at ssh://user@prod, skipped"* ]]
    grep -qx 'docker --context default image prune -af' "$HOME/docker.calls"
    ! grep -q prod "$HOME/docker.calls"
}

@test "clean_containers: sizes are read again once stopped containers are removed" {
    stub docker '
ctx=""; [ "$1" = --context ] && { ctx=$2; shift 2; }
case "$1" in
    context) echo "default|unix:///run/default.sock" ;;
    info) exit 0 ;;
    system) if [ -e "$HOME/pruned" ]; then printf "Images|2GB\nContainers|0B\nLocal Volumes|1GB\n"
            else printf "Images|0B\nContainers|1GB\nLocal Volumes|0B\n"; fi ;;
    container) touch "$HOME/pruned" ;;
    *) echo "docker $*" >>"$HOME/docker.calls" ;;
esac'
    run sys_lib 'ui_confirm() { echo "ASK $1 $3"; return 0; }; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"ASK Remove unused docker images? (reclaimable: 2GB)"* ]]
    [[ "$output" == *"ASK Remove unused docker volumes (their data is lost)? (reclaimable: 1GB)"* ]]
}

@test "clean_containers: podman is never tried through sudo" {
    stub podman 'exit 1'
    stub sudo 'echo "$*" >>"$HOME/sudo.calls"; exit 0'
    run sys_lib 'sys_is_root() { return 1; }; ARG_YES=1; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"podman: not reachable, skipped"* ]]
    [ ! -e "$HOME/sudo.calls" ]
}

@test "clean_containers: on macOS docker is never tried through sudo, Docker Desktop data is reported" {
    stub uname 'echo Darwin'
    stub docker 'exit 1'
    stub du 'echo "2097152	$2"'
    mkdir -p "$HOME/Library/Containers/com.docker.docker"
    run sys_lib 'sys_is_root() { return 1; }; DRY_RUN=1; ARG_YES=1; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"docker: daemon not reachable"* ]]
    [[ "$output" != *"sudo"* ]]
    [[ "$output" == *"Docker Desktop keeps 2.0G in $HOME/Library/Containers/com.docker.docker"* ]]
}

@test "clean_containers: podman has no build cache task and prunes volumes without -a" {
    stub podman 'case "$1" in info) exit 0 ;; system) printf "Images|1GB\nContainers|1GB\nLocal Volumes|1GB\n" ;; *) echo "podman $*" >>"$HOME/podman.calls" ;; esac'
    run sys_lib 'ui_confirm() { echo "ASK $1"; return 0; }; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" != *"build cache"* ]]
    [ "$(cat "$HOME/podman.calls")" = "podman container prune -f
podman image prune -af
podman volume prune -f" ]
}

@test "clean_containers: Docker Desktop data of 1M is reported, under 1M is not" {
    docker_stub default default 'Images|0B\nContainers|0B\nLocal Volumes|0B\nBuild Cache|0B\n'
    mkdir -p "$HOME/.docker/desktop"
    stub du 'echo "1023	$2"'
    run sys_lib 'ARG_YES=1; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to clean"* ]]
    [[ "$output" != *"Docker Desktop"* ]]
    stub du 'echo "1024	$2"'
    run sys_lib 'ARG_YES=1; clean_containers'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Docker Desktop keeps 1M in $HOME/.docker/desktop"* ]]
}
