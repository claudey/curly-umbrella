class StatusBadgeComponent < ApplicationComponent
  def initialize(status:, size: "sm", pulse: false, outlined: false)
    @status = status
    @size = size
    @pulse = pulse
    @outlined = outlined
  end

  STATUS_CONFIGS = {
    # Application statuses
    "draft" => { color: "gray", label: "Draft", icon: "document" },
    "submitted" => { color: "blue", label: "Submitted", icon: "paper-airplane" },
    "under_review" => { color: "yellow", label: "Under Review", icon: "clock" },
    "approved" => { color: "green", label: "Approved", icon: "check-circle" },
    "rejected" => { color: "red", label: "Rejected", icon: "x-circle" },

    # Quote statuses
    "pending" => { color: "yellow", label: "Pending", icon: "clock" },
    "quoted" => { color: "blue", label: "Quoted", icon: "document-text" },
    "accepted" => { color: "green", label: "Accepted", icon: "check-circle" },
    "expired" => { color: "gray", label: "Expired", icon: "x-circle" },

    # Distribution statuses
    "viewed" => { color: "blue", label: "Viewed", icon: "eye" },
    "ignored" => { color: "gray", label: "Ignored", icon: "x-mark" },

    # Payment/Policy statuses
    "active" => { color: "green", label: "Active", icon: "check-circle" },
    "inactive" => { color: "gray", label: "Inactive", icon: "pause-circle" },
    "cancelled" => { color: "red", label: "Cancelled", icon: "x-circle" },

    # Priority levels
    "high" => { color: "red", label: "High Priority", icon: "exclamation" },
    "medium" => { color: "yellow", label: "Medium Priority", icon: "minus" },
    "low" => { color: "green", label: "Low Priority", icon: "arrow-down" },

    # Risk levels
    "low_risk" => { color: "green", label: "Low Risk", icon: "shield-check" },
    "medium_risk" => { color: "yellow", label: "Medium Risk", icon: "shield-exclamation" },
    "high_risk" => { color: "red", label: "High Risk", icon: "exclamation-triangle" }
  }.freeze

  private

  def config
    STATUS_CONFIGS[@status] || { color: "gray", label: @status.humanize, icon: "question-mark-circle" }
  end

  def badge_classes
    base = "badge"
    base += " badge-#{size_class}"
    base += " #{color_class}"
    base += " animate-pulse" if @pulse
    base
  end

  def size_class
    case @size
    when "xs" then "xs"
    when "sm" then "sm"
    when "md" then "md"
    when "lg" then "lg"
    else "sm"
    end
  end

  def color_class
    color = config[:color]
    if @outlined
      "badge-outline badge-#{badge_color_mapping(color)}"
    else
      "badge-#{badge_color_mapping(color)}"
    end
  end

  def badge_color_mapping(color)
    case color
    when "gray" then "neutral"
    when "blue" then "info"
    when "yellow" then "warning"
    when "green" then "success"
    when "red" then "error"
    else "neutral"
    end
  end

  def label
    config[:label]
  end

  def status_icon
    config[:icon]
  end
end
