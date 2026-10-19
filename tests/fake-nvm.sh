# Fake nvm.sh, copied to $HOMEBREW_PREFIX/opt/nvm/nvm.sh by the brew stub when
# nvm is "installed". `nvm install` creates a Node folder that `nvm version`
# then finds.
nvm() {
  echo "nvm $*" >> "$STUB_LOG"
  case "$1" in
    version) if [ -d "$NVM_DIR/versions/node/lts" ]; then echo v24.0.0; else echo N/A; fi ;;
    install) mkdir -p "$NVM_DIR/versions/node/lts" ;;
  esac
}
