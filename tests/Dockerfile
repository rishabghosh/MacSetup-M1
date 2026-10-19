# Test image for the setup scripts. Uses bash 3.2, the version macOS ships,
# so anything that only works on newer bash fails here too.
FROM bash:3.2.57

RUN apk add --no-cache python3 shellcheck \
 # macOS has bash at /bin/bash; ensure_homebrew calls it by that path.
 && ln -sf /usr/local/bin/bash /bin/bash

WORKDIR /repo
CMD ["bash", "tests/suite.sh"]
