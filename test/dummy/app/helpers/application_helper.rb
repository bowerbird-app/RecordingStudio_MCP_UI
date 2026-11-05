module ApplicationHelper
  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    content_for(:title, title)

    if back_url.present?
      flat_pack_page_nav(
        round: true,
        style: :default,
        back_href: back_url,
        back_tooltip: back_label
      )
    end

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
    end

    register_page_nav(
      role: :secondary,
      component: FlatPack::Button::Component.new(
        text: "Sign out",
        style: :ghost,
        size: :md,
        href: main_app.destroy_user_session_path,
        data: { turbo_method: :delete }
      )
    )
  end
end
