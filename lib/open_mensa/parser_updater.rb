class OpenMensa::ParserUpdater < OpenMensa::BaseUpdater
  attr_reader :parser
  attr_reader :sources_added, :sources_created, :sources_updated, :sources_deleted

  def initialize(parser)
    @parser = parser
    reset_stats
  end

  def reset_stats
    super
    @sources_added = 0
    @sources_created = 0
    @sources_updated = 0
    @sources_deleted = 0
  end

  def messageable
    @parser
  end

  def fetch!
    @data = OpenMensa::FeedLoader.new(parser, :index_url).load!
  rescue OpenMensa::FeedLoader::FeedLoadError => error
    error.cause.tap do |err|
      case err
        when URI::InvalidURIError
          Rails.logger.warn "Invalid Index-URI (#{parser.index_url}) for #{parser.name}"
          @errors << FeedInvalidUrlError.create(messageable: parser)
        when OpenURI::HTTPError
          create_fetch_error! err.message, err.message.to_i
        else
          create_fetch_error! err.message
      end
    end
    false
  end

  def parse!
    @document = JSON.parse data.read
  rescue JSON::JSONError => err
    create_validation_error! :no_json, err.message
    false
  end

  def validate!
    @document.each do |name, url|
      next if url.nil?
      next if url.is_a?(String) and url.present?
      create_validation_error! :invalid_json, 'URL must be a string or null'
      return false
    end
    true
  end

  def sync
    return false unless fetch! && parse! && validate!

    sources = source_mapping
    document.each do |name, url|
      if sources.key? name
        update_source sources.fetch(name), url
        sources.delete name
      else
        new_source name, url
      end
    end
    sources.each do |name, source|
      archive_source source
    end
    true
  end

  def stats
    {
      new: @sources_added,
      created: @sources_created,
      updated: @sources_updated,
      archived: @sources_deleted
    }
  end

  private

  def source_mapping
    @parser.sources.inject({}) do |memo, source|
      memo[source.name] = source
      memo
    end
  end

  def update_source(source, url)
    if source.canteen.state == 'archived'
      SourceListChanged.create! messageable: source,
                                kind: :source_reactivated,
                                name: source.name,
                                url: url
      source.canteen.update_attributes! state: 'wanted'
      @sources_added += 1
    end
    return if url.nil?
    if source.meta_url != url
      FeedUrlUpdatedInfo.create! messageable: source,
                                 old_url: source.meta_url,
                                 new_url: url
      source.update_attribute :meta_url, url
      @sources_updated += 1
    end
  end

  def new_source(name, url)
    SourceListChanged.create! messageable: @parser,
                              kind: :new_source,
                              name: name, url: url
    unless url.nil?
      source = Source.new parser: @parser, name: name, meta_url: url
      if OpenMensa::SourceCreator.new(source).sync
        @sources_created += 1
        @sources_added -= 1
      end
    end
    @sources_added += 1
  end

  def archive_source(source)
    return if source.canteen.state == 'archived'
    SourceListChanged.create! messageable: source,
                              kind: :source_archived,
                              name: source.name
    source.canteen.update_attributes! state: 'archived'
    @sources_deleted += 1
  end
end
