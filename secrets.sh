#!/usr/bin/env bash
# Helper script for managing SOPS-encrypted secrets
set -euo pipefail

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
export EDITOR="${EDITOR:-nano}"

usage() {
  echo "Usage: ./secrets.sh <command>"
  echo ""
  echo "Commands:"
  echo "  edit <chart>     Edit secrets for a chart (monitoring, code-server, homepage)"
  echo "  view <chart>     View decrypted secrets for a chart (no changes)"
  echo "  edit-all         Edit all secret files one by one"
  echo "  setup-cluster    Load the age key into the ArgoCD namespace"
  echo ""
  echo "Examples:"
  echo "  ./secrets.sh edit monitoring"
  echo "  ./secrets.sh view code-server"
  echo "  ./secrets.sh setup-cluster"
}

get_path() {
  local chart="$1"
  local path="charts/${chart}/secrets.yaml"
  if [[ ! -f "$path" ]]; then
    echo "Error: $path not found" >&2
    exit 1
  fi
  echo "$path"
}

case "${1:-}" in
  edit)
    [[ -z "${2:-}" ]] && { usage; exit 1; }
    sops "$(get_path "$2")"
    ;;
  view)
    [[ -z "${2:-}" ]] && { usage; exit 1; }
    sops --decrypt "$(get_path "$2")"
    ;;
  edit-all)
    for chart in monitoring code-server homepage; do
      echo "--- Editing $chart secrets ---"
      sops "charts/${chart}/secrets.yaml"
    done
    ;;
  setup-cluster)
    echo "Loading age key into argocd namespace..."
    kubectl -n argocd create secret generic argocd-age-key \
      --from-file=keys.txt="$SOPS_AGE_KEY_FILE" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "Done. Now apply the repo-server patch:"
    echo "  kubectl apply -f bootstrap/argocd-helm-secrets.yaml"
    echo "  kubectl -n argocd rollout restart deployment argocd-repo-server"
    ;;
  *)
    usage
    ;;
esac
