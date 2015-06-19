require_relative 'test_helper'

class BinaryTest < Minitest::Test

  # Any entities created in the tests should use one of these slugs, to ensure
  # that they get torn down.
  SLUGS = %w(bin1 bin2 bin3 bin4 bin5 bin6 bin7 bin8 bin9 bin10)

  def setup
    @config = ActiveMedusa::Configuration.instance
    @http = HTTPClient.new
  end

  def teardown
    SLUGS.each do |slug|
      @http.delete("#{@config.fedora_url}/#{slug}") rescue nil
      @http.delete("#{@config.fedora_url}/#{slug}/fcr:tombstone") rescue nil
    end
  end

  # initialize

  def test_initialize_parameters
    type = 'image/jpeg'
    bs = Bytestream.new(media_type: type)
    assert_equal type, bs.media_type
  end

  def test_rdf_graph_initialization
    bs = Bytestream.new
    found = false
    bs.rdf_graph.each_statement do |st|
      if st.predicate.to_s == @config.class_predicate
        assert_equal 'http://example.org/Bytestream', st.object.to_s
        found = true
      end
    end
    flunk unless found
  end

  # repository_metadata_url

  def test_repository_metadata_url
    url = "http://example.org/#{SLUGS[0]}"
    bs = Bytestream.new(repository_url: url)
    assert_equal url + '/fcr:metadata', bs.repository_metadata_url

    bs = Bytestream.new(repository_url: nil)
    assert_nil bs.repository_metadata_url
  end

  # save

  def test_save_with_uploaded_file
    slug = SLUGS[0]
    media_type = 'text/plain'
    expected_url = "#{@config.fedora_url}/#{slug}"
    bs = Bytestream.new(parent_url: @config.fedora_url,
                        upload_pathname: __FILE__,
                        requested_slug: slug,
                        media_type: media_type)
    bs.save!
    assert_equal expected_url, bs.repository_url
    assert bs.persisted?

    response = @http.get(expected_url)
    assert_equal media_type, response.header['Content-Type'].first
    assert response.body.include?('assert response.body.include?')
  end

  def test_save_with_external_resource
    slug = SLUGS[0]
    expected_url = "#{@config.fedora_url}/#{slug}"
    resource_url = 'https://www.google.com'
    bs = Bytestream.new(parent_url: @config.fedora_url,
                        external_resource_url: resource_url,
                        requested_slug: slug)
    bs.save!
    assert_equal expected_url, bs.repository_url
    assert bs.persisted?

    response = @http.get(expected_url)
    assert_equal 307, response.status
    assert response.header['Location'].first.include?(resource_url)
  end

  def test_save_with_nothing_to_save_raises_error
    bs = Bytestream.new
    assert_raises RuntimeError do
      bs.save!
    end
    assert_nil bs.repository_url
    assert !bs.persisted?
  end

  def test_save_loads_rdf_graph
    bs = Bytestream.new(parent_url: @config.fedora_url,
                        upload_pathname: __FILE__,
                        requested_slug: SLUGS[0],
                        media_type: 'text/plain')
    assert bs.rdf_graph.count == 1
    bs.save!
    assert bs.rdf_graph.count > 10
  end

end
