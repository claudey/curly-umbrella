class Ui::CustomerPortalLayoutComponent < ApplicationComponent
  renders_one :header
  renders_one :sidebar  
  renders_one :main_content
  renders_one :footer

  def initialize(
    title: "Customer Portal",
    user: nil,
    active_nav: nil,
    show_breadcrumbs: true,
    mobile_friendly: true,
    theme: "light",
    class: nil,
    **options
  )
    @title = title
    @user = user
    @active_nav = active_nav
    @show_breadcrumbs = show_breadcrumbs
    @mobile_friendly = mobile_friendly
    @theme = theme
    @additional_classes = binding.local_variable_get(:class)
    @options = options
  end

  private

  attr_reader :title, :user, :active_nav, :show_breadcrumbs, :mobile_friendly, :theme, 
              :additional_classes, :options

  def layout_classes
    classes = ["min-h-screen", "bg-base-100"]
    classes << additional_classes if additional_classes
    classes.compact.join(" ")
  end

  def drawer_classes
    classes = ["drawer"]
    classes << "drawer-mobile" if mobile_friendly
    classes.join(" ")
  end

  def navbar_classes
    "navbar bg-base-200 shadow-sm border-b border-base-300"
  end

  def sidebar_classes
    "drawer-side z-20"
  end

  def sidebar_content_classes
    "menu min-h-full w-64 p-4 bg-base-200 text-base-content border-r border-base-300"
  end

  def main_classes
    "drawer-content flex flex-col min-h-screen"
  end

  def content_classes
    "flex-1 p-6"
  end

  def show_header?
    header.present? || user.present? || title.present?
  end

  def show_sidebar?
    sidebar.present? || navigation_items.any?
  end

  def show_footer?
    footer.present?
  end

  def navigation_items
    [
      {
        label: "Dashboard",
        path: customer_portal_path,
        icon: :home,
        active: active_nav == "dashboard"
      },
      {
        label: "My Policies",
        path: customer_policies_path,
        icon: :document_text,
        active: active_nav == "policies"
      },
      {
        label: "Claims",
        path: customer_claims_path,
        icon: :exclamation_triangle,
        active: active_nav == "claims"
      },
      {
        label: "Applications",
        path: customer_applications_path,
        icon: :clipboard_document_list,
        active: active_nav == "applications"
      },
      {
        label: "Documents",
        path: customer_documents_path,
        icon: :folder,
        active: active_nav == "documents"
      },
      {
        label: "Profile",
        path: customer_profile_path,
        icon: :user,
        active: active_nav == "profile"
      },
      {
        label: "Support",
        path: customer_support_path,
        icon: :chat_bubble_left_right,
        active: active_nav == "support"
      }
    ]
  end

  def breadcrumbs
    case active_nav
    when "dashboard"
      [{ label: "Dashboard", current: true }]
    when "policies"
      [
        { label: "Dashboard", path: customer_portal_path },
        { label: "My Policies", current: true }
      ]
    when "claims"
      [
        { label: "Dashboard", path: customer_portal_path },
        { label: "Claims", current: true }
      ]
    when "applications"
      [
        { label: "Dashboard", path: customer_portal_path },
        { label: "Applications", current: true }
      ]
    when "documents"
      [
        { label: "Dashboard", path: customer_portal_path },
        { label: "Documents", current: true }
      ]
    when "profile"
      [
        { label: "Dashboard", path: customer_portal_path },
        { label: "Profile", current: true }
      ]
    when "support"
      [
        { label: "Dashboard", path: customer_portal_path },
        { label: "Support", current: true }
      ]
    else
      [{ label: "Dashboard", current: true }]
    end
  end

  def customer_portal_path
    "/customer"
  end

  def customer_policies_path
    "/customer/policies"
  end

  def customer_claims_path
    "/customer/claims"
  end

  def customer_applications_path
    "/customer/applications"
  end

  def customer_documents_path
    "/customer/documents"
  end

  def customer_profile_path
    "/customer/profile"
  end

  def customer_support_path
    "/customer/support"
  end
end