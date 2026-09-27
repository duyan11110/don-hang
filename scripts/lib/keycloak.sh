# Plumbing, not a lesson: sourced by the scripts that need a token from Keycloak.
# The donhang-app client allows one way to get a token, the authorization code
# flow with PKCE, so this does what a browser does: open Keycloak's login
# page, submit its form, and stop at the redirect to read the code from it.
# scripts/backend/oauth-code-flow.sh walks through the same steps one by one.

keycloak=http://localhost:8180/realms/donhang/protocol/openid-connect
redirect_uri=http://localhost:8081/auth/callback

# keycloak_sign_in <email> [scope]: print Keycloak's token response (JSON).
keycloak_sign_in() {
  local email=$1 scope=${2:-openid}
  local jar verifier challenge form location code
  jar=$(mktemp)
  verifier=$(openssl rand -hex 32)
  challenge=$(printf %s "$verifier" | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')

  form=$(curl -sS --fail -c "$jar" -b "$jar" -G "$keycloak/auth" \
      -d client_id=donhang-app -d response_type=code --data-urlencode "scope=$scope" \
      --data-urlencode "redirect_uri=$redirect_uri" \
      -d "code_challenge=$challenge" -d code_challenge_method=S256 \
    | sed -nE 's/.*id="kc-form-login".* action="([^"]*)".*/\1/p' | sed 's/&amp;/\&/g')
  location=$(curl -sS -c "$jar" -b "$jar" -o /dev/null -w '%{redirect_url}' \
      --data-urlencode "username=$email" -d password=donhang-dev-password "$form")
  rm -f "$jar"
  code=$(printf %s "$location" | sed -nE 's/.*[?&]code=([^&]+).*/\1/p')
  if [ -z "$code" ]; then
    echo "keycloak_sign_in: Keycloak gave no code for $email" >&2
    return 1
  fi

  curl -sS --fail "$keycloak/token" \
    -d grant_type=authorization_code -d client_id=donhang-app \
    --data-urlencode "redirect_uri=$redirect_uri" \
    -d "code=$code" -d "code_verifier=$verifier"
}

# keycloak_access_token <email>: print only the access token.
keycloak_access_token() {
  keycloak_sign_in "$1" | sed -E 's/.*"access_token":"([^"]+)".*/\1/'
}

# jwt_claims <token>: print the claims of a JWT, the JSON in its middle part
# (base64url-encoded). Uses jq, which the lab box has.
jwt_claims() {
  printf %s "$1" | jq -R 'split(".")[1] | gsub("-"; "+") | gsub("_"; "/") | @base64d | fromjson'
}
