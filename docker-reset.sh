#!/usr/bin/env bash
# ==============================================================================
#  docker-k8s-full-reset.sh — Docker reset ALWAYS; optional K8s (minikube/kind)
# ------------------------------------------------------------------------------
#  Mode:
#    - Interactive menu was removed.
#    - CHOICE is fixed to "1": Kubernetes (auto-detect: minikube/kind) + Docker.
#
#  Notes:
#    - No system service stop/start, no data-dir wipe.
#    - Minimal, readable output (no timestamps/boxes).
#    - Non-critical errors are handled gracefully.
# ==============================================================================

set -u -o pipefail

# ---------- Colors & Emojis (TTY only) ----------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_CYN=$'\033[36m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""; C_RED=""; C_GRN=""; C_YEL=""; C_CYN=""
fi
EM_OK="✅"; EM_WARN="⚠️"; EM_ERR="❌"; EM_DKR="🐳"; EM_K8S="☸️"; EM_BROOM="🧹"; EM_STOP="🛑"; EM_FIRE="🔥"

# ---------- Small helpers -----------------------------------------------------
log()  { printf "  %s•%s %s\n" "$C_DIM" "$C_RESET" "$*"; }
info() { printf "  %s%s%s %s\n" "$C_CYN" "$EM_K8S" "$C_RESET" "$*"; }
ok()   { printf "  %s%s%s %s\n" "$C_GRN" "$EM_OK" "$C_RESET" "$*"; }
warn() { printf "  %s%s%s %s\n" "$C_YEL" "$EM_WARN" "$C_RESET" "$*"; }
err()  { printf "  %s%s%s %s\n" "$C_RED" "$EM_ERR" "$C_RESET" "$*"; }
hr()   { printf "%s\n" "----------------------------------------------------------------"; }

run() { "$@"; rc=$?; [ $rc -eq 0 ] || warn "Command failed (exit $rc): $*"; return 0; }
supports() { command -v "$1" >/dev/null 2>&1; }
network_exists() { supports docker && docker network inspect "$1" >/dev/null 2>&1; }

# ---------- Snapshots for final summary ---------------------------------------
DOCKER_CNT_BEFORE=0; DOCKER_IMG_BEFORE=0; DOCKER_VOL_BEFORE=0; DOCKER_NET_BEFORE=0
K8S_MINI_BEFORE=0;  K8S_KIND_BEFORE=0
K8S_MINI_AFTER=0;   K8S_KIND_AFTER=0
DID_K8S=0

docker_snapshot_before() {
  if supports docker; then
    DOCKER_CNT_BEFORE="$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')"
    DOCKER_IMG_BEFORE="$(docker images -aq 2>/dev/null | wc -l | tr -d ' ')"
    DOCKER_VOL_BEFORE="$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')"
    DOCKER_NET_BEFORE="$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')"
  fi
}

count_minikube_clusters() {
  if ! supports minikube; then echo 0; return 0; fi
  if minikube profile list -o json >/dev/null 2>&1; then
    minikube profile list -o json 2>/dev/null | tr -d '\n' | grep -o '"Name"' | wc -l | tr -d ' '
  else
    minikube profile list 2>/dev/null | awk -F'|' 'NR>2 && $2 ~ /[A-Za-z0-9._-]/ {c++} END{print (c+0)}'
  fi
}
count_kind_clusters() {
  if ! supports kind; then echo 0; return 0; fi
  kind get clusters 2>/dev/null | wc -l | tr -d ' '
}
k8s_snapshot_before() { K8S_MINI_BEFORE="$(count_minikube_clusters || echo 0)"; K8S_KIND_BEFORE="$(count_kind_clusters || echo 0)"; }
k8s_snapshot_after()  { K8S_MINI_AFTER="$(count_minikube_clusters || echo 0)";  K8S_KIND_AFTER="$(count_kind_clusters || echo 0)"; }

# ---------- Kubernetes reset (no services, no data-dir wipe) -------------------
reset_minikube() {
  if supports minikube; then
    ok "minikube detected. Deleting all profiles…"
    run minikube delete --all --purge >/dev/null 2>&1
    run minikube delete --all >/dev/null 2>&1
    if supports docker; then
      left="$(docker ps -a --filter 'name=minikube' -q 2>/dev/null || true)"
      if [ -n "${left:-}" ]; then printf "%s\n" "$left" | xargs -n 100 docker rm -fv >/dev/null 2>&1 || true; fi
      if network_exists minikube; then run docker network rm minikube >/dev/null 2>&1; else log "minikube network not present."; fi
      mini_imgs="$(docker images 'gcr.io/k8s-minikube/*' -q 2>/dev/null || true)"
      if [ -n "${mini_imgs:-}" ]; then printf "%s\n" "$mini_imgs" | xargs -n 100 docker rmi -f >/dev/null 2>&1 || true; fi
    fi
  else
    log "minikube not found. Skipping."
  fi
}
reset_kind() {
  if supports kind; then
    ok "kind detected. Deleting clusters…"
    run kind delete clusters --all >/dev/null 2>&1
    clusters="$(kind get clusters 2>/dev/null || true)"
    if [ -n "${clusters:-}" ]; then
      while IFS= read -r name; do [ -n "$name" ] && run kind delete cluster --name "$name" >/dev/null 2>&1; done <<< "$clusters"
    fi
    if supports docker; then
      left="$(docker ps -a --filter 'name=^kind-' -q 2>/dev/null || true)"
      if [ -n "${left:-}" ]; then printf "%s\n" "$left" | xargs -n 100 docker rm -fv >/dev/null 2>&1 || true; fi
      if network_exists kind; then run docker network rm kind >/dev/null 2>&1; else log "kind network not present."; fi
      nodes="$(docker images 'kindest/node' -q 2>/dev/null || true)"
      if [ -n "${nodes:-}" ]; then printf "%s\n" "$nodes" | xargs -n 100 docker rmi -f >/dev/null 2>&1 || true; fi
    fi
  else
    log "kind not found. Skipping."
  fi
}
reset_kubernetes_auto() {
  DID_K8S=1
  echo
  echo "== KUBERNETES RESET $EM_K8S =="
  echo
  reset_minikube
  reset_kind
  echo
  ok "Kubernetes reset completed."
}

# ---------- Docker reset (no services, no data-dir wipe) -----------------------
reset_docker() {
  if ! supports docker; then err "docker not found in PATH. Skipping Docker reset."; return 0; fi

  c0="$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ' )"
  i0="$(docker images -aq 2>/dev/null | wc -l | tr -d ' ')"
  v0="$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')"
  n0="$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')"

  echo
  echo "== DOCKER FULL RESET $EM_DKR =="
  echo
  warn "This will delete containers, images, caches, volumes, and prune networks. $EM_BROOM"
  echo

  # Containers
  info "Stopping and removing ALL containers $EM_STOP"
  running="$(docker ps -q 2>/dev/null || true)"
  if [ -n "${running:-}" ]; then printf "%s\n" "$running" | xargs -n 100 docker stop >/dev/null 2>&1 || true; else log "No running containers."; fi
  allc="$(docker ps -aq 2>/dev/null || true)"
  if [ -n "${allc:-}" ]; then printf "%s\n" "$allc" | xargs -n 100 docker rm -fv >/dev/null 2>&1 || true; else log "No containers to remove."; fi

  echo
  # Images
  info "Removing ALL images $EM_FIRE"
  imgs="$(docker images -aq 2>/dev/null || true)"
  if [ -n "${imgs:-}" ]; then printf "%s\n" "$imgs" | xargs -n 100 docker rmi -f >/dev/null 2>&1 || true; else log "No images to remove."; fi

  echo
  # Caches
  info "Pruning builder/buildx/system caches $EM_BROOM"
  run docker builder prune -a -f >/dev/null 2>&1
  if docker buildx version >/dev/null 2>&1; then run docker buildx prune -a -f >/dev/null 2>&1; else warn "docker buildx not available; skipping buildx prune."; fi
  run docker system prune -f >/dev/null 2>&1

  echo
  # Volumes & networks
  info "Removing ALL volumes and pruning unused networks $EM_BROOM"
  vols="$(docker volume ls -q 2>/dev/null || true)"
  if [ -n "${vols:-}" ]; then printf "%s\n" "$vols" | xargs -n 100 docker volume rm >/dev/null 2>&1 || true; else log "No volumes to remove."; fi
  run docker network prune -f >/dev/null 2>&1

  c1="$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')"
  i1="$(docker images -aq 2>/dev/null | wc -l | tr -d ' ')"
  v1="$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')"
  n1="$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')"

  echo
  hr
  echo
  echo "DOCKER STEP SUMMARY $EM_OK"
  echo
  printf "  Containers : %s%s%s → %s%s%s   (deleted: %s%s%s)\n" "$C_BOLD" "$c0" "$C_RESET" "$C_BOLD" "$c1" "$C_RESET" "$C_BOLD" "$((c0 - c1))" "$C_RESET"
  printf "  Images     : %s%s%s → %s%s%s   (deleted: %s%s%s)\n" "$C_BOLD" "$i0" "$C_RESET" "$C_BOLD" "$i1" "$C_RESET" "$C_BOLD" "$((i0 - i1))" "$C_RESET"
  printf "  Volumes    : %s%s%s → %s%s%s   (deleted: %s%s%s)\n" "$C_BOLD" "$v0" "$C_RESET" "$C_BOLD" "$v1" "$C_RESET" "$C_BOLD" "$((v0 - v1))" "$C_RESET"
  nd=$((n0 - n1)); [ $nd -lt 0 ] && nd=0
  printf "  Networks   : %s%s%s → %s%s%s   (removed : %s%s%s)\n" "$C_BOLD" "$n0" "$C_RESET" "$C_BOLD" "$n1" "$C_RESET" "$C_BOLD" "$nd" "$C_RESET"
  echo
  hr
  echo
  ok "Docker reset complete. $EM_BROOM $EM_FIRE"
}

# ---------- Menu (fixed selection) --------------------------------------------
# Prompt input removed: always run full reset
CHOICE="1"

# ---------- Snapshots BEFORE any changes --------------------------------------
docker_snapshot_before
if [ "${CHOICE:-2}" = "1" ]; then k8s_snapshot_before; fi

# ---------- Execute ------------------------------------------------------------
if [ "${CHOICE:-2}" = "1" ]; then
  reset_kubernetes_auto
fi
reset_docker

# ---------- Final summary ------------------------------------------------------
echo
hr
echo
echo "FINAL SUMMARY $EM_OK"
echo

if [ "${CHOICE:-2}" = "1" ]; then
  DID_K8S=1
fi
if [ $DID_K8S -eq 1 ]; then
  k8s_snapshot_after
  md=$(( K8S_MINI_BEFORE - K8S_MINI_AFTER )); [ $md -lt 0 ] && md=0
  kd=$(( K8S_KIND_BEFORE - K8S_KIND_AFTER )); [ $kd -lt 0 ] && kd=0
  echo "  Kubernetes (clusters)"
  printf "    minikube : %s%s%s → %s%s%s   (deleted: %s%s%s)\n" "$C_BOLD" "$K8S_MINI_BEFORE" "$C_RESET" "$C_BOLD" "$K8S_MINI_AFTER" "$C_RESET" "$C_BOLD" "$md" "$C_RESET"
  printf "    kind     : %s%s%s → %s%s%s   (deleted: %s%s%s)\n" "$C_BOLD" "$K8S_KIND_BEFORE" "$C_RESET" "$C_BOLD" "$K8S_KIND_AFTER" "$C_RESET" "$C_BOLD" "$kd" "$C_RESET"
  echo
fi

if supports docker; then
  DOCKER_CNT_AFTER="$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')"
  DOCKER_IMG_AFTER="$(docker images -aq 2>/dev/null | wc -l | tr -d ' ')"
  DOCKER_VOL_AFTER="$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')"
  DOCKER_NET_AFTER="$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')"
  dc=$((DOCKER_CNT_BEFORE - DOCKER_CNT_AFTER)); [ $dc -lt 0 ] && dc=0
  di=$((DOCKER_IMG_BEFORE - DOCKER_IMG_AFTER)); [ $di -lt 0 ] && di=0
  dv=$((DOCKER_VOL_BEFORE - DOCKER_VOL_AFTER)); [ $dv -lt 0 ] && dv=0
  dn=$((DOCKER_NET_BEFORE - DOCKER_NET_AFTER)); [ $dn -lt 0 ] && dn=0

  echo "  Docker"
  printf "    Containers: %s%s%s → %s%s%s   (deleted: %s%s%s)\n" "$C_BOLD" "$DOCKER_CNT_BEFORE" "$C_RESET" "$C_BOLD" "$DOCKER_CNT_AFTER" "$C_RESET" "$C_BOLD" "$dc" "$C_RESET"
  printf "    Images    : %s%s%s → %s%s%s   (deleted: %s%s%s)\n" "$C_BOLD" "$DOCKER_IMG_BEFORE" "$C_RESET" "$C_BOLD" "$DOCKER_IMG_AFTER" "$C_RESET" "$C_BOLD" "$di" "$C_RESET"
  printf "    Volumes   : %s%s%s → %s%s%s   (deleted: %s%s%s)\n" "$C_BOLD" "$DOCKER_VOL_BEFORE" "$C_RESET" "$C_BOLD" "$DOCKER_VOL_AFTER" "$C_RESET" "$C_BOLD" "$dv" "$C_RESET"
  printf "    Networks  : %s%s%s → %s%s%s   (removed : %s%s%s)\n"   "$C_BOLD" "$DOCKER_NET_BEFORE" "$C_RESET" "$C_BOLD" "$DOCKER_NET_AFTER" "$C_RESET" "$C_BOLD" "$dn" "$C_RESET"
  echo
fi

hr
echo
ok "Done. $EM_BROOM"
