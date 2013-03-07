module ApplicationHelper

  def t(*attrs)
    options = attrs.extract_options!
    id      = attrs.join '.'

    options[:default] ||= "[[#{id}]]"
    I18n.t(id, options.merge({ raise: true, default: nil})).html_safe
  rescue
    Rails.logger.warn $!
    options[:default].to_s
  end

  def avatar(*attrs)
    options = attrs.extract_options!
    user    = attrs.first || User.current
    if user
      content_tag :span, class: 'avatar', style: options[:size] ? "width: #{options[:size]}px; height: #{options[:size]}px;" : '' do
        image_tag user.gravatar_url(options).to_s,
          alt:   user.name,
          class: 'avatar',
          style: options[:size] ? "width: #{options[:size]}px; height: #{options[:size]}px;" : ''
      end
    else
      content_tag :span, class: 'avatar', style: "width: #{options[:size]}px; height: #{options[:size]}px;" do
        ""
      end
    end
  end

  def title
    "#{@title} - #{OpenMensa::TITLE}" unless @title
    OpenMensa::TITLE
  end

  def body_classes
    ["#{controller.controller_name}_controller", "#{params[:action] || 'unknown'}_action", @layout].join(' ').strip
  end

  def map(canteens, options = {})
    canteens = [ canteens ] unless canteens.respond_to?(:map)
    markers = canteens.map do |canteen|
      {
        lat: canteen.latitude,
        lng: canteen.longitude,
        title: canteen.name,
        url: canteen_path(canteen)
      }
    end
    content_tag :div, nil, class: "map index_map", id: (options[:id] || "map"), data: { map: (options[:id] || "map"), markers: markers.to_json}
  end
end
