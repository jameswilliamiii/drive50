module ApplicationHelper
  # Pagy v43: Helper methods are available directly on @pagy instance
  # No need to include a separate module - methods like @pagy.info_tag work automatically
  # local_time helper is automatically available from the local_time gem

  # SVG Icon helpers
  def icon_moon(options = {})
    size = options[:size] || 20
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-moon #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" fill="#{color}" stroke="#{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>))
  end

  def icon_sun(options = {})
    size = options[:size] || 20
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-sun #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle cx="12" cy="12" r="5" fill="#{color}" stroke="#{color}" stroke-width="1.5"/>
      <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" stroke="#{color}" stroke-width="1.5" stroke-linecap="round"/>
    </svg>))
  end

  def icon_check(options = {})
    size = options[:size] || 16
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-check #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M20 6L9 17l-5-5" stroke="#{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>))
  end

  def icon_menu(options = {})
    size = options[:size] || 24
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-menu #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M3 12h18M3 6h18M3 18h18" stroke="#{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>))
  end

  def icon_close(options = {})
    size = options[:size] || 24
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-close #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M18 6L6 18M6 6l12 12" stroke="#{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>))
  end

  def icon_info(options = {})
    size = options[:size] || 16
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-info #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle cx="12" cy="12" r="10" stroke="#{color}" stroke-width="2"/>
      <path d="M12 16v-4M12 8h.01" stroke="#{color}" stroke-width="2" stroke-linecap="round"/>
    </svg>))
  end

  def icon_dots(options = {})
    size = options[:size] || 20
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-dots #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle cx="12" cy="5" r="1.5" fill="#{color}"/>
      <circle cx="12" cy="12" r="1.5" fill="#{color}"/>
      <circle cx="12" cy="19" r="1.5" fill="#{color}"/>
    </svg>))
  end

  def icon_home(options = {})
    size = options[:size] || 24
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-home #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" stroke="#{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M9 22V12h6v10" stroke="#{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>))
  end

  def icon_list(options = {})
    size = options[:size] || 24
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-list #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" stroke="#{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>))
  end

  def icon_plus(options = {})
    size = options[:size] || 24
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    raw(%(<svg class="icon icon-plus #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M12 5v14M5 12h14" stroke="#{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>))
  end
end
