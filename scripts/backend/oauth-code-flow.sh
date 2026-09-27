#!/usr/bin/env bash
# Get tokens for customer 1 with the authorization code flow and PKCE, curl playing the browser, then show what Keycloak refuses.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

keycloak=http://localhost:8180/realms/donhang/protocol/openid-connect
redirect_uri=http://localhost:8081/auth/callback

# lesson: backend.l2.authorization-code-flow
# PKCE: the app keeps a random code_verifier to itself and puts only its
# SHA-256 hash, the code_challenge, into the browser's address bar.
new_verifier() { openssl rand -hex 32; }
challenge_of() {
  printf %s "$1" | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '='
}

# The browser's part: open Keycloak's authorization endpoint, fill in the
# customer's email and password on Keycloak's login form, then stop at the
# redirect back to the app instead of following it. Prints that redirect.
log_in() {
  local jar form
  jar=$(mktemp)
  form=$(curl -sS -c "$jar" -b "$jar" -G "$keycloak/auth" \
      -d client_id=donhang-app -d response_type=code -d scope=openid \
      --data-urlencode "redirect_uri=$redirect_uri" \
      -d "code_challenge=$1" -d code_challenge_method=S256 \
    | sed -nE 's/.*id="kc-form-login".* action="([^"]*)".*/\1/p' | sed 's/&amp;/\&/g')
  curl -sS -c "$jar" -b "$jar" -o /dev/null -w '%{redirect_url}' \
    --data-urlencode username=anh.tran@example.com -d password=donhang-dev-password "$form"
  rm -f "$jar"
}
code_in() { printf %s "$1" | sed -nE 's/.*[?&]code=([^&]+).*/\1/p'; }

# lesson: backend.l2.authorization-code-flow
# The app's part: a direct POST to the token endpoint with the code and the
# verifier. Keycloak hashes the verifier and compares it with the challenge.
exchange() {
  curl -sS "$keycloak/token" \
    -d grant_type=authorization_code -d client_id=donhang-app \
    --data-urlencode "redirect_uri=$redirect_uri" -d "code=$1" -d "code_verifier=$2"
}

verifier=$(new_verifier)
echo "== 1. the browser logs in at Keycloak and is sent back with a code"
redirect=$(log_in "$(challenge_of "$verifier")")
echo "redirected to: $redirect"
echo

echo "== 2. the app exchanges that code and its code_verifier for tokens"
# Keycloak lists the granted scopes in no fixed order; sorted, they read the
# same on every run.
exchange "$(code_in "$redirect")" "$verifier" \
  | jq '{token_type, expires_in, scope: (.scope | split(" ") | sort | join(" ")),
         access_token: (.access_token[0:20] + "...")}'
echo

echo "== 3. a code stolen on its way back, exchanged without the app's verifier"
redirect=$(log_in "$(challenge_of "$(new_verifier)")")
exchange "$(code_in "$redirect")" "$(new_verifier)"
echo
echo

echo "== 4. an authorization request with no code_challenge"
curl -sS -o /dev/null -w 'redirected to: %{redirect_url}\n' -G "$keycloak/auth" \
  -d client_id=donhang-app -d response_type=code -d scope=openid \
  --data-urlencode "redirect_uri=$redirect_uri"
echo

echo "== 5. an authorization request with a redirect_uri donhang-app never registered"
page=$(curl -sS -w '\n%{http_code}' -G "$keycloak/auth" \
  -d client_id=donhang-app -d response_type=code -d scope=openid \
  --data-urlencode "redirect_uri=http://attacker.example/callback" \
  -d "code_challenge=$(challenge_of "$verifier")" -d code_challenge_method=S256)
echo "Keycloak shows an error page instead of redirecting: $(grep -o 'Invalid parameter: [a-z_]*' <<<"$page")"
echo "  -> $(tail -n 1 <<<"$page")"
