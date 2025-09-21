module Ui::DesignSystem
  # Design System Constants and Configuration

  # Color Palette - Extended from DaisyUI with modern additions
  COLORS = {
    # Primary Brand Colors
    primary: {
      50 => "#eff6ff",
      100 => "#dbeafe",
      200 => "#bfdbfe",
      300 => "#93c5fd",
      400 => "#60a5fa",
      500 => "#3b82f6", # Primary
      600 => "#2563eb",
      700 => "#1d4ed8",
      800 => "#1e40af",
      900 => "#1e3a8a"
    },

    # Secondary Colors
    secondary: {
      50 => "#f8fafc",
      100 => "#f1f5f9",
      200 => "#e2e8f0",
      300 => "#cbd5e1",
      400 => "#94a3b8",
      500 => "#64748b",
      600 => "#475569",
      700 => "#334155",
      800 => "#1e293b",
      900 => "#0f172a"
    },

    # Success Colors
    success: {
      50 => "#f0fdf4",
      100 => "#dcfce7",
      200 => "#bbf7d0",
      300 => "#86efac",
      400 => "#4ade80",
      500 => "#22c55e", # Success
      600 => "#16a34a",
      700 => "#15803d",
      800 => "#166534",
      900 => "#14532d"
    },

    # Warning Colors
    warning: {
      50 => "#fffbeb",
      100 => "#fef3c7",
      200 => "#fde68a",
      300 => "#fcd34d",
      400 => "#fbbf24",
      500 => "#f59e0b", # Warning
      600 => "#d97706",
      700 => "#b45309",
      800 => "#92400e",
      900 => "#78350f"
    },

    # Error Colors
    error: {
      50 => "#fef2f2",
      100 => "#fee2e2",
      200 => "#fecaca",
      300 => "#fca5a5",
      400 => "#f87171",
      500 => "#ef4444", # Error
      600 => "#dc2626",
      700 => "#b91c1c",
      800 => "#991b1b",
      900 => "#7f1d1d"
    },

    # Neutral Colors
    neutral: {
      50 => "#fafafa",
      100 => "#f5f5f5",
      200 => "#e5e5e5",
      300 => "#d4d4d4",
      400 => "#a3a3a3",
      500 => "#737373",
      600 => "#525252",
      700 => "#404040",
      800 => "#262626",
      900 => "#171717"
    }
  }.freeze

  # Typography Scale
  TYPOGRAPHY = {
    font_families: {
      sans: %w[Inter ui-sans-serif system-ui],
      serif: %w[Georgia ui-serif serif],
      mono: %w[JetBrains\ Mono ui-monospace monospace]
    },

    font_sizes: {
      xs: "0.75rem",      # 12px
      sm: "0.875rem",     # 14px
      base: "1rem",       # 16px
      lg: "1.125rem",     # 18px
      xl: "1.25rem",      # 20px
      '2xl': "1.5rem",    # 24px
      '3xl': "1.875rem",  # 30px
      '4xl': "2.25rem",   # 36px
      '5xl': "3rem",      # 48px
      '6xl': "3.75rem",   # 60px
      '7xl': "4.5rem",    # 72px
      '8xl': "6rem",      # 96px
      '9xl': "8rem"       # 128px
    },

    font_weights: {
      thin: 100,
      extralight: 200,
      light: 300,
      normal: 400,
      medium: 500,
      semibold: 600,
      bold: 700,
      extrabold: 800,
      black: 900
    },

    line_heights: {
      none: 1,
      tight: 1.25,
      snug: 1.375,
      normal: 1.5,
      relaxed: 1.625,
      loose: 2
    }
  }.freeze

  # Spacing Scale (based on 4px grid)
  SPACING = {
    0 => "0",
    1 => "0.25rem",     # 4px
    2 => "0.5rem",      # 8px
    3 => "0.75rem",     # 12px
    4 => "1rem",        # 16px
    5 => "1.25rem",     # 20px
    6 => "1.5rem",      # 24px
    8 => "2rem",        # 32px
    10 => "2.5rem",     # 40px
    12 => "3rem",       # 48px
    16 => "4rem",       # 64px
    20 => "5rem",       # 80px
    24 => "6rem",       # 96px
    32 => "8rem",       # 128px
    40 => "10rem",      # 160px
    48 => "12rem",      # 192px
    56 => "14rem",      # 224px
    64 => "16rem"       # 256px
  }.freeze

  # Border Radius
  BORDER_RADIUS = {
    none: "0",
    sm: "0.125rem",     # 2px
    default: "0.25rem", # 4px
    md: "0.375rem",     # 6px
    lg: "0.5rem",       # 8px
    xl: "0.75rem",      # 12px
    '2xl': "1rem",      # 16px
    '3xl': "1.5rem",    # 24px
    full: "9999px"
  }.freeze

  # Shadows
  SHADOWS = {
    sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
    default: "0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)",
    md: "0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)",
    lg: "0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)",
    xl: "0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)",
    '2xl': "0 25px 50px -12px rgb(0 0 0 / 0.25)",
    inner: "inset 0 2px 4px 0 rgb(0 0 0 / 0.05)",
    none: "0 0 #0000"
  }.freeze

  # Breakpoints for Responsive Design
  BREAKPOINTS = {
    sm: "640px",   # Small screens
    md: "768px",   # Medium screens
    lg: "1024px",  # Large screens
    xl: "1280px",  # Extra large screens
    '2xl': "1536px" # 2X large screens
  }.freeze

  # Animation & Transitions
  ANIMATIONS = {
    transition: {
      none: "none",
      all: "all 150ms cubic-bezier(0.4, 0, 0.2, 1)",
      colors: "color, background-color, border-color, text-decoration-color, fill, stroke 150ms cubic-bezier(0.4, 0, 0.2, 1)",
      opacity: "opacity 150ms cubic-bezier(0.4, 0, 0.2, 1)",
      shadow: "box-shadow 150ms cubic-bezier(0.4, 0, 0.2, 1)",
      transform: "transform 150ms cubic-bezier(0.4, 0, 0.2, 1)"
    },

    duration: {
      75 => "75ms",
      100 => "100ms",
      150 => "150ms",
      200 => "200ms",
      300 => "300ms",
      500 => "500ms",
      700 => "700ms",
      1000 => "1000ms"
    },

    ease: {
      linear: "linear",
      in: "cubic-bezier(0.4, 0, 1, 1)",
      out: "cubic-bezier(0, 0, 0.2, 1)",
      'in-out': "cubic-bezier(0.4, 0, 0.2, 1)"
    }
  }.freeze

  # Component Variants
  COMPONENT_VARIANTS = {
    button: {
      sizes: {
        xs: { padding: "0.25rem 0.5rem", font_size: "xs" },
        sm: { padding: "0.375rem 0.75rem", font_size: "sm" },
        md: { padding: "0.5rem 1rem", font_size: "base" },
        lg: { padding: "0.625rem 1.25rem", font_size: "lg" },
        xl: { padding: "0.75rem 1.5rem", font_size: "xl" }
      },

      variants: {
        primary: {
          bg: "primary-500",
          text: "white",
          hover_bg: "primary-600",
          focus_ring: "primary-300"
        },
        secondary: {
          bg: "secondary-100",
          text: "secondary-900",
          hover_bg: "secondary-200",
          focus_ring: "secondary-300"
        },
        success: {
          bg: "success-500",
          text: "white",
          hover_bg: "success-600",
          focus_ring: "success-300"
        },
        warning: {
          bg: "warning-500",
          text: "white",
          hover_bg: "warning-600",
          focus_ring: "warning-300"
        },
        error: {
          bg: "error-500",
          text: "white",
          hover_bg: "error-600",
          focus_ring: "error-300"
        },
        outline: {
          bg: "transparent",
          text: "primary-600",
          border: "primary-300",
          hover_bg: "primary-50",
          focus_ring: "primary-300"
        },
        ghost: {
          bg: "transparent",
          text: "secondary-600",
          hover_bg: "secondary-100",
          focus_ring: "secondary-300"
        }
      }
    },

    card: {
      variants: {
        default: {
          bg: "white",
          border: "neutral-200",
          shadow: "sm",
          radius: "lg"
        },
        elevated: {
          bg: "white",
          border: "none",
          shadow: "lg",
          radius: "xl"
        },
        outlined: {
          bg: "white",
          border: "neutral-300",
          shadow: "none",
          radius: "lg"
        },
        filled: {
          bg: "neutral-50",
          border: "none",
          shadow: "none",
          radius: "lg"
        }
      }
    },

    input: {
      sizes: {
        sm: { padding: "0.375rem 0.75rem", font_size: "sm" },
        md: { padding: "0.5rem 0.875rem", font_size: "base" },
        lg: { padding: "0.625rem 1rem", font_size: "lg" }
      },

      states: {
        default: {
          border: "neutral-300",
          focus_border: "primary-500",
          focus_ring: "primary-200"
        },
        error: {
          border: "error-300",
          focus_border: "error-500",
          focus_ring: "error-200"
        },
        success: {
          border: "success-300",
          focus_border: "success-500",
          focus_ring: "success-200"
        },
        disabled: {
          bg: "neutral-100",
          border: "neutral-200",
          text: "neutral-400"
        }
      }
    },

    badge: {
      sizes: {
        sm: { padding: "0.125rem 0.375rem", font_size: "xs" },
        md: { padding: "0.25rem 0.5rem", font_size: "sm" },
        lg: { padding: "0.375rem 0.75rem", font_size: "base" }
      },

      variants: {
        default: { bg: "neutral-100", text: "neutral-800" },
        primary: { bg: "primary-100", text: "primary-800" },
        success: { bg: "success-100", text: "success-800" },
        warning: { bg: "warning-100", text: "warning-800" },
        error: { bg: "error-100", text: "error-800" },
        info: { bg: "secondary-100", text: "secondary-800" }
      }
    }
  }.freeze

  # Icon Sizes
  ICON_SIZES = {
    xs: "12",
    sm: "16",
    md: "20",
    lg: "24",
    xl: "32",
    '2xl': "48"
  }.freeze

  # Layout Utilities
  LAYOUT = {
    container: {
      sm: "640px",
      md: "768px",
      lg: "1024px",
      xl: "1280px",
      '2xl': "1536px"
    },

    z_index: {
      0 => "0",
      10 => "10",
      20 => "20",
      30 => "30",
      40 => "40",
      50 => "50",
      auto: "auto"
    }
  }.freeze

  class << self
    # Helper methods for accessing design tokens

    def color(name, shade = 500)
      COLORS.dig(name, shade) || COLORS.dig(:neutral, shade)
    end

    def spacing(size)
      SPACING[size] || SPACING[4]
    end

    def font_size(size)
      TYPOGRAPHY[:font_sizes][size] || TYPOGRAPHY[:font_sizes][:base]
    end

    def shadow(size)
      SHADOWS[size] || SHADOWS[:default]
    end

    def radius(size)
      BORDER_RADIUS[size] || BORDER_RADIUS[:default]
    end

    def breakpoint(size)
      BREAKPOINTS[size]
    end

    def component_variant(component, variant_type, variant_name)
      COMPONENT_VARIANTS.dig(component, variant_type, variant_name) || {}
    end

    def generate_css_variables
      css_vars = []

      # Generate color variables
      COLORS.each do |color_name, shades|
        shades.each do |shade, value|
          css_vars << "--color-#{color_name}-#{shade}: #{value};"
        end
      end

      # Generate spacing variables
      SPACING.each do |size, value|
        css_vars << "--spacing-#{size}: #{value};"
      end

      # Generate typography variables
      TYPOGRAPHY[:font_sizes].each do |size, value|
        css_vars << "--font-size-#{size}: #{value};"
      end

      css_vars.join("\n")
    end

    def generate_tailwind_config
      {
        theme: {
          extend: {
            colors: COLORS,
            spacing: SPACING,
            fontSize: TYPOGRAPHY[:font_sizes],
            fontFamily: TYPOGRAPHY[:font_families],
            fontWeight: TYPOGRAPHY[:font_weights],
            lineHeight: TYPOGRAPHY[:line_heights],
            borderRadius: BORDER_RADIUS,
            boxShadow: SHADOWS,
            screens: BREAKPOINTS,
            transitionDuration: ANIMATIONS[:duration],
            transitionTimingFunction: ANIMATIONS[:ease],
            zIndex: LAYOUT[:z_index]
          }
        }
      }
    end

    # Accessibility helpers
    def focus_ring_classes(color = :primary)
      "focus:outline-none focus:ring-2 focus:ring-#{color}-500 focus:ring-opacity-50"
    end

    def sr_only_classes
      "sr-only"
    end

    # Component utility classes
    def button_classes(variant: :primary, size: :md, disabled: false)
      base_classes = %w[
        inline-flex items-center justify-center
        font-medium rounded-lg transition-colors
        focus:outline-none focus:ring-2 focus:ring-offset-2
        disabled:opacity-50 disabled:cursor-not-allowed
      ]

      variant_config = component_variant(:button, :variants, variant)
      size_config = component_variant(:button, :sizes, size)

      # Build classes based on configuration
      classes = base_classes.dup
      classes << "bg-#{variant_config[:bg]}" if variant_config[:bg]
      classes << "text-#{variant_config[:text]}" if variant_config[:text]
      classes << "hover:bg-#{variant_config[:hover_bg]}" if variant_config[:hover_bg]
      classes << "focus:ring-#{variant_config[:focus_ring]}" if variant_config[:focus_ring]
      classes << "text-#{size_config[:font_size]}" if size_config[:font_size]
      classes << "border border-#{variant_config[:border]}" if variant_config[:border]

      classes.join(" ")
    end

    def card_classes(variant: :default)
      base_classes = %w[
        rounded-lg border transition-shadow
      ]

      variant_config = component_variant(:card, :variants, variant)

      classes = base_classes.dup
      classes << "bg-#{variant_config[:bg]}" if variant_config[:bg]
      classes << "border-#{variant_config[:border]}" if variant_config[:border]
      classes << "shadow-#{variant_config[:shadow]}" if variant_config[:shadow]
      classes << "rounded-#{variant_config[:radius]}" if variant_config[:radius]

      classes.join(" ")
    end

    def input_classes(size: :md, state: :default)
      base_classes = %w[
        block w-full rounded-lg border transition-colors
        placeholder-neutral-400 focus:outline-none focus:ring-2
      ]

      size_config = component_variant(:input, :sizes, size)
      state_config = component_variant(:input, :states, state)

      classes = base_classes.dup
      classes << "text-#{size_config[:font_size]}" if size_config[:font_size]
      classes << "border-#{state_config[:border]}" if state_config[:border]
      classes << "focus:border-#{state_config[:focus_border]}" if state_config[:focus_border]
      classes << "focus:ring-#{state_config[:focus_ring]}" if state_config[:focus_ring]
      classes << "bg-#{state_config[:bg]}" if state_config[:bg]
      classes << "text-#{state_config[:text]}" if state_config[:text]

      classes.join(" ")
    end

    def badge_classes(variant: :default, size: :md)
      base_classes = %w[
        inline-flex items-center rounded-full font-medium
      ]

      variant_config = component_variant(:badge, :variants, variant)
      size_config = component_variant(:badge, :sizes, size)

      classes = base_classes.dup
      classes << "bg-#{variant_config[:bg]}" if variant_config[:bg]
      classes << "text-#{variant_config[:text]}" if variant_config[:text]
      classes << "text-#{size_config[:font_size]}" if size_config[:font_size]

      classes.join(" ")
    end
  end
end
