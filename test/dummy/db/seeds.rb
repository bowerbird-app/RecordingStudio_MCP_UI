# frozen_string_literal: true

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

grant_or_find_access = lambda do |recording, actor, role|
  existing = RecordingStudioAccessible.access_recordings_for_actor(
    recording: recording,
    actor: actor
  ).first
  return existing if existing.present?

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

admin_email = ENV.fetch("DUMMY_ADMIN_EMAIL", "admin@admin.com")
admin_password = ENV.fetch("DUMMY_ADMIN_PASSWORD", "Password")

user = User.find_or_create_by!(email: admin_email) do |record|
  record.password = admin_password
  record.password_confirmation = admin_password
end

studio = Workspace.find_or_create_by!(name: "Studio Workspace")
docs = Workspace.find_or_create_by!(name: "Docs Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")
admin_root = AdminRoot.find_or_create_by!(name: "Admin")

oauth_client = RecordingStudioOauth::OauthClient.find_or_initialize_by(name: "Seed MCP App")
oauth_client.redirect_uris = [ "http://127.0.0.1:3000/callback" ]
oauth_client.confidential = false
oauth_client.api_key = "public"
oauth_client.save!

previous_actor = Current.actor
Current.actor = user

begin
  studio_root = RecordingStudio.root_recording_for(studio)
  docs_root = RecordingStudio.root_recording_for(docs)
  admin_recording = RecordingStudio.root_recording_for(admin_root)

  studio_access = grant_or_find_access.call(studio_root, user, :admin)
  grant_or_find_access.call(docs_root, user, :admin)
  grant_or_find_access.call(admin_recording, user, :admin)

  folder_recording = find_or_record_child.call(folder, studio_root, studio_root)
  find_or_record_child.call(page, studio_root, folder_recording)

  if defined?(RecordingStudioSiteSettings) && RecordingStudioSiteSettings.name_for(studio_root) != "Studio"
    RecordingStudioSiteSettings.update!(studio_root, name: "Studio", actor: user)
  end

  pkce_challenge = RecordingStudioOauth::Pkce.s256_challenge("V#{"a" * 42}")
  unless RecordingStudioOauth::OauthAuthorization.exists?(
    oauth_client: oauth_client,
    manager_actor: user,
    manager_access_recording: studio_access,
    revoked_at: nil
  )
    connected = RecordingStudioOauth::Services::CreateOauthAuthorization.call(
      oauth_client: oauth_client,
      manager_actor: user,
      access_recording: studio_access,
      role: "edit",
      redirect_uri: oauth_client.redirect_uris.first,
      code_challenge: pkce_challenge,
      code_challenge_method: "S256"
    )
    raise connected.error if connected.failure?
  end
ensure
  Current.actor = previous_actor
end

beach = Project.find_or_create_by!(title: "Beach House") do |record|
  record.description = "A coastal recording project."
  record.status = "active"
end
cabin = Project.find_or_create_by!(title: "Mountain Cabin") do |record|
  record.description = "A quiet room with a view."
  record.status = "draft"
end

puts "Seeded: #{admin_email} (set DUMMY_ADMIN_EMAIL / DUMMY_ADMIN_PASSWORD to override)"
puts "Seeded: Seed MCP App client_id=#{oauth_client.client_id}"
puts "Seeded: Studio Workspace (Connected)"
puts "Seeded: MCP at /recording_studio_mcp"
puts "Seeded: Project '#{beach.title}' and '#{cabin.title}'"
