%w( rubygems rest_client json redis nokogiri).each{ |lib| require lib }
%w( caching common reddit ).each{ |file| load File.expand_path( File.join( File.dirname( __FILE__ ), 'share_counts', "#{file}.rb" ) ) } # TODO: replace load with require

module ShareCounts

  extend Common
  extend Caching

  def self.extract_count *args
    extract_info(*args)
  end

  def self.supported_networks
    %w(reddit twitter facebook linkedin googleplus pinterest)
  end

  def self.reddit url, raise_exceptions = false
    # This can fail if site has no comments on reddit
    try('reddit', url, raise_exceptions) {
      extract_count(from_json( 'http://www.reddit.com/api/info.json', :url => url ),
                    :selector => 'data/children/data/score')
    }
  end

  def self.reddit_with_permalink url, raise_exceptions = false
    ShareCounts::Reddit.info_for url, raise_exceptions
  end

  def self.pinterest url, raise_exceptions = false
    try('pinterest', url, raise_exceptions) {
      extract_count from_json( 'http://api.pinterest.com/v1/urls/count.json', :url => url, :callback => 'pinterest_count'),
        :selector => 'count'
    }
  end


  def self.twitter url, raise_exceptions = false
    try('twitter', url, raise_exceptions) {
      extract_count from_json( 'http://cdn.api.twitter.com/1/urls/count.json', :url => url),
        :selector => 'count'
    }
  end

  def self.facebook url, raise_exceptions = false
    try('facebook', url, raise_exceptions) {
      # FB graph api return nil when page is not shared!
      extract_count(from_json('https://graph.facebook.com/', :id => url, :format => :json), :selector => 'shares').to_i
    }
  end

  def self.linkedin url, raise_exceptions = false
    try('linkedin', url, raise_exceptions) {
      extract_count from_json('http://www.linkedin.com/countserv/count/share',
        :url => url, :format => 'json' ), :selector => 'count'
    }
  end

  def self.googleplus url, raise_exceptions = false
    try('googleplus', url, raise_exceptions) {
      Nokogiri::HTML.parse(
          make_request("https://apis.google.com/u/0/_/+1/fastbutton", :usegapi => 1, :url => url )
      ).css('#aggregateCount').text.to_i
    }
  end

  def self.all url
    supported_networks.inject({}) { |r, c| r[c.to_sym] = ShareCounts.send(c, url); r }
  end

  def self.selected url, selections
    selections.map{|name| name.downcase}.select{|name| supported_networks.include? name.to_s}.inject({}) {
       |r, c| r[c.to_sym] = ShareCounts.send(c, url); r }
  end

end
