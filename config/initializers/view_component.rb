require "view_component"

ViewComponent::Base.config.generate = {
  preview: true,
  stimulus_controller: true,
  sidecar: true,
  locale: false,
  helper: false
}

ViewComponent::Base.config.preview_paths << Rails.root.join("spec/components/previews")
ViewComponent::Base.config.show_previews = Rails.env.development?