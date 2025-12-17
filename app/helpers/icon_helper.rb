module IconHelper
  # SVG icon definitions
  ICONS = {
    moon: '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" fill="%{color}" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    sun: '<circle cx="12" cy="12" r="5" fill="%{color}" stroke="%{color}" stroke-width="1.5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" stroke="%{color}" stroke-width="1.5" stroke-linecap="round"/>',
    check: '<path d="M20 6L9 17l-5-5" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    menu: '<path d="M3 12h18M3 6h18M3 18h18" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    close: '<path d="M18 6L6 18M6 6l12 12" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    info: '<circle cx="12" cy="12" r="10" stroke="%{color}" stroke-width="2"/><path d="M12 16v-4M12 8h.01" stroke="%{color}" stroke-width="2" stroke-linecap="round"/>',
    dots: '<circle cx="12" cy="5" r="1.5" fill="%{color}"/><circle cx="12" cy="12" r="1.5" fill="%{color}"/><circle cx="12" cy="19" r="1.5" fill="%{color}"/>',
    home: '<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M9 22V12h6v10" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    list: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    plus: '<path d="M12 5v14M5 12h14" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    arrow_left: '<path d="M19 12H5M12 19l-7-7 7-7" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
  }.freeze

  # Generic icon renderer
  # Usage: icon(:moon, size: 20, color: "blue", class: "my-class")
  def icon(name, **options)
    size = options[:size] || default_size_for(name)
    color = options[:color] || "currentColor"
    classes = options[:class] || ""

    svg_content = ICONS[name]
    raise ArgumentError, "Unknown icon: #{name}" unless svg_content

    formatted_content = svg_content % { color: color }

    raw(<<~SVG.squish)
      <svg class="icon icon-#{name.to_s.dasherize} #{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        #{formatted_content}
      </svg>
    SVG
  end

  # Backwards compatibility - delegate to generic icon method
  def icon_moon(options = {})
    icon(:moon, **options)
  end

  def icon_sun(options = {})
    icon(:sun, **options)
  end

  def icon_check(options = {})
    icon(:check, **options)
  end

  def icon_menu(options = {})
    icon(:menu, **options)
  end

  def icon_close(options = {})
    icon(:close, **options)
  end

  def icon_info(options = {})
    icon(:info, **options)
  end

  def icon_dots(options = {})
    icon(:dots, **options)
  end

  def icon_home(options = {})
    icon(:home, **options)
  end

  def icon_list(options = {})
    icon(:list, **options)
  end

  def icon_plus(options = {})
    icon(:plus, **options)
  end

  def icon_arrow_left(options = {})
    icon(:arrow_left, **options)
  end

  private

  def default_size_for(name)
    case name
    when :check, :info then 16
    when :dots then 20
    else 24
    end
  end
end
