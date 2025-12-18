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
    # Heroicon home (solid)
    home_solid: '<path d="M11.47 3.841a.75.75 0 0 1 1.06 0l8.69 8.69a.75.75 0 1 0 1.06-1.061l-8.689-8.69a2.25 2.25 0 0 0-3.182 0l-8.69 8.69a.75.75 0 1 0 1.061 1.06l8.69-8.689Z" fill="%{color}"/><path d="m12 5.432 8.159 8.159c.03.03.06.058.091.086v6.198c0 1.035-.84 1.875-1.875 1.875H15a.75.75 0 0 1-.75-.75v-4.5a.75.75 0 0 0-.75-.75h-3a.75.75 0 0 0-.75.75V21a.75.75 0 0 1-.75.75H5.625a1.875 1.875 0 0 1-1.875-1.875v-6.198a2.29 2.29 0 0 0 .091-.086L12 5.432Z" fill="%{color}"/>',
    # Heroicon queue-list (outline)
    list: '<path d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 0 1 0 3.75H5.625a1.875 1.875 0 0 1 0-3.75Z" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    # Heroicon queue-list (solid)
    list_solid: '<path d="M5.625 3.75a2.625 2.625 0 1 0 0 5.25h12.75a2.625 2.625 0 0 0 0-5.25H5.625ZM3.75 11.25a.75.75 0 0 0 0 1.5h16.5a.75.75 0 0 0 0-1.5H3.75ZM3 15.75a.75.75 0 0 1 .75-.75h16.5a.75.75 0 0 1 0 1.5H3.75a.75.75 0 0 1-.75-.75ZM3.75 18.75a.75.75 0 0 0 0 1.5h16.5a.75.75 0 0 0 0-1.5H3.75Z" fill="%{color}"/>',
    # Heroicon cog-6-tooth (outline)
    settings: '<path d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 0 1 1.37.49l1.296 2.247a1.125 1.125 0 0 1-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 0 1 0 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 0 1-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 0 1-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 0 1-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 0 1-1.369-.49l-1.297-2.247a1.125 1.125 0 0 1 .26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 0 1 0-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 0 1-.26-1.43l1.297-2.247a1.125 1.125 0 0 1 1.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28Z" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    # Heroicon cog-6-tooth (solid)
    settings_solid: '<path fill-rule="evenodd" d="M11.078 2.25c-.917 0-1.699.663-1.85 1.567L9.05 4.889c-.02.12-.115.26-.297.348a7.493 7.493 0 0 0-.986.57c-.166.115-.334.126-.45.083L6.3 5.508a1.875 1.875 0 0 0-2.282.819l-.922 1.597a1.875 1.875 0 0 0 .432 2.385l.84.692c.095.078.17.229.154.43a7.598 7.598 0 0 0 0 1.139c.015.2-.59.352-.153.43l-.841.692a1.875 1.875 0 0 0-.432 2.385l.922 1.597a1.875 1.875 0 0 0 2.282.818l1.019-.382c.115-.043.283-.031.45.082.312.214.641.405.985.57.182.088.277.228.297.35l.178 1.071c.151.904.933 1.567 1.85 1.567h1.844c.916 0 1.699-.663 1.85-1.567l.178-1.072c.02-.12.114-.26.297-.349.344-.165.673-.356.985-.57.167-.114.335-.125.45-.082l1.02.382a1.875 1.875 0 0 0 2.28-.819l.923-1.597a1.875 1.875 0 0 0-.432-2.385l-.84-.692c-.095-.078-.17-.229-.154-.43a7.614 7.614 0 0 0 0-1.139c-.016-.2.059-.352.153-.43l.84-.692c.708-.582.891-1.59.433-2.385l-.922-1.597a1.875 1.875 0 0 0-2.282-.818l-1.02.382c-.114.043-.282.031-.449-.083a7.49 7.49 0 0 0-.985-.57c-.183-.087-.277-.227-.297-.348l-.179-1.072a1.875 1.875 0 0 0-1.85-1.567h-1.843ZM12 15.75a3.75 3.75 0 1 0 0-7.5 3.75 3.75 0 0 0 0 7.5Z" clip-rule="evenodd" fill="%{color}"/>',
    plus: '<path d="M12 5v14M5 12h14" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    arrow_left: '<path d="M19 12H5M12 19l-7-7 7-7" stroke="%{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    # Heroicon stop (outline)
    stop: '<path d="M5.25 7.5A2.25 2.25 0 0 1 7.5 5.25h9a2.25 2.25 0 0 1 2.25 2.25v9a2.25 2.25 0 0 1-2.25 2.25h-9a2.25 2.25 0 0 1-2.25-2.25v-9Z" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    # Heroicon arrow-down-tray style export (outline)
    export: '<path d="m9 13.5 3 3m0 0 3-3m-3 3v-6m1.06-4.19-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke="%{color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    # Heroicon arrow-down-tray style export (solid)
    export_solid: '<path fill-rule="evenodd" d="M19.5 21a3 3 0 0 0 3-3V9a3 3 0 0 0-3-3h-5.379a.75.75 0 0 1-.53-.22L11.47 3.66A2.25 2.25 0 0 0 9.879 3H4.5a3 3 0 0 0-3 3v12a3 3 0 0 0 3 3h15Zm-6.75-10.5a.75.75 0 0 0-1.5 0v4.19l-1.72-1.72a.75.75 0 0 0-1.06 1.06l3 3a.75.75 0 0 0 1.06 0l3-3a.75.75 0 1 0-1.06-1.06l-1.72 1.72V10.5Z" clip-rule="evenodd" fill="%{color}"/>'
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

  def icon_stop(options = {})
    icon(:stop, **options)
  end

  # Bottom nav helper: switches between outline and solid versions based on active state
  def bottom_nav_icon(name, active:, **options)
    variant = active ? :"#{name}_solid" : name
    icon(variant, **options)
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
