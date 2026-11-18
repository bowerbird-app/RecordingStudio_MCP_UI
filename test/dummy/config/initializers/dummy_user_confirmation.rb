# frozen_string_literal: true

# Users 0.36 adds Devise :confirmable on the host user class at boot.
# This demo does not send confirmation mail. Confirm accounts it creates.
Rails.application.config.to_prepare do
  next if User.respond_to?(:dummy_accounts_confirmed)

  User.define_singleton_method(:dummy_accounts_confirmed) { true }
  User.before_validation do
    skip_confirmation! if respond_to?(:skip_confirmation!) && confirmed_at.blank?
  end
end
