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
    # Heroicon home (outline)
    home: '<path d="m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    # Heroicon queue-list (outline)
    list: '<path d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 0 1 0 3.75H5.625a1.875 1.875 0 0 1 0-3.75Z" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    # Heroicon cog-6-tooth (outline)
    settings: '<path d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 0 1 1.37.49l1.296 2.247a1.125 1.125 0 0 1-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 0 1 0 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 0 1-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 0 1-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 0 1-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 0 1-1.369-.49l-1.297-2.247a1.125 1.125 0 0 1 .26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 0 1 0-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 0 1-.26-1.43l1.297-2.247a1.125 1.125 0 0 1 1.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28Z" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    plus: '<path d="M12 5v14M5 12h14" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    arrow_left: '<path d="M19 12H5M12 19l-7-7 7-7" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    # Heroicon arrow-down-tray style export (outline)
    export: '<path d="m9 13.5 3 3m0 0 3-3m-3 3v-6m1.06-4.19-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
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

  def icon_settings(options = {})
    icon(:settings, **options)
  end

  def icon_plus(options = {})
    icon(:plus, **options)
  end

  def icon_arrow_left(options = {})
    icon(:arrow_left, **options)
  end

  def icon_export(options = {})
    icon(:export, **options)
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
