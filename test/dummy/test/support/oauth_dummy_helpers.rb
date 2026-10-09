# frozen_string_literal: true

module OauthDummyHelpers
  TEST_PASSWORD = "OauthDummyPassword!2026"

  def create_user(email: "oauth-user-#{SecureRandom.hex(4)}@example.com")
    User.find_or_create_by!(email: email) do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end
  end

  def grant_or_bootstrap_access!(recording:, actor:, role:)
    existing = RecordingStudioAccessible.access_recordings_for_actor(
      recording: recording,
      actor: actor
    ).first
    return existing if existing.present? && existing.recordable.role.to_s == role.to_s

    if role.to_s == "admin"
      bootstrap = RecordingStudioAccessible.bootstrap_owner_access!(
        recording: recording,
        actor: actor
      )
      return bootstrap.value if bootstrap.success?
    end

    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role.to_s,
      manager_actor: actor
    )
    return result.value if result.success?

    raise result.error
  end

  def create_access_recording_for(user:, workspace_name: "Workspace #{SecureRandom.hex(4)}", role: :admin)
    Current.actor = user
    workspace = Workspace.create!(name: workspace_name)
    root_recording = RecordingStudio.root_recording_for(workspace)
    access_recording = grant_or_bootstrap_access!(
      recording: root_recording,
      actor: user,
      role: role
    )

    [ root_recording, access_recording ]
  end

  def create_oauth_client(name: "Demo App", redirect_uris: [ "http://127.0.0.1/callback" ], api: "public")
    client = RecordingStudioOauth::OauthClient.create!(
      name: name,
      confidential: false,
      redirect_uris: redirect_uris,
      api_key: api.to_s
    )
    [ client, nil ]
  end

  def pkce_pair
    verifier = "V#{SecureRandom.urlsafe_base64(32)}"
    verifier = verifier.ljust(43, "a")
    {
      verifier: verifier,
      challenge: RecordingStudioOauth::Pkce.s256_challenge(verifier)
    }
  end

  def approve_delegated_oauth(oauth_client:, user:, access_recording:, role: "view", redirect_uri: "http://127.0.0.1/callback", pkce: nil)
    pkce ||= pkce_pair
    result = RecordingStudioOauth::Services::CreateOauthAuthorization.call(
      oauth_client: oauth_client,
      manager_actor: user,
      access_recording: access_recording,
      role: role,
      redirect_uri: redirect_uri,
      code_challenge: pkce.fetch(:challenge),
      code_challenge_method: "S256"
    )
    raise result.error unless result.success?

    result.value.merge(pkce: pkce, redirect_uri: redirect_uri)
  end

  def issue_delegated_token(oauth_client:, user:, access_recording:, role: "edit", pkce: nil)
    pkce ||= pkce_pair
    approved = approve_delegated_oauth(
      oauth_client: oauth_client,
      user: user,
      access_recording: access_recording,
      role: role,
      pkce: pkce
    )

    post "/recording_studio_api/oauth/token", params: {
      grant_type: "authorization_code",
      client_id: oauth_client.client_id,
      code: approved.fetch(:code),
      redirect_uri: "http://127.0.0.1/callback",
      code_verifier: pkce.fetch(:verifier)
    }
    raise "token exchange failed: #{response.body}" unless response.successful?

    JSON.parse(response.body).fetch("access_token")
  end

  def rpc(method, **params)
    { jsonrpc: "2.0", id: SecureRandom.random_number(1_000), method: method, params: params }
  end

  def json_headers(extra = {})
    { "Content-Type" => "application/json", "Accept" => "application/json" }.merge(extra)
  end

  def tool_payload(payload)
    result = payload.fetch("result")
    return result.fetch("structuredContent") if result["structuredContent"].present?

    JSON.parse(result.dig("content", 0, "text"))
  end
end
