require 'active_medusa/configuration'
require 'active_medusa/fedora'
require 'rdf'

class Seeder

  def initialize(config)
    @http = ActiveMedusa::Fedora.client
    @config = config
  end

  def seed
    apply_indexing_transform

    # Seed data structure:
    #
    # item 1
    #   bytestream 1
    #   bytestream 2
    # collection 1
    #   item 2
    #     bytestream 3
    #     item 3
    #       bytestream 4
    #
    item_1 = Item.new(parent_url: @config.fedora_url, requested_slug: 'item1',
                      full_text: 'lorem ipsum')
    item_1.rdf_graph << RDF::Statement.new(
        RDF::URI(), RDF::URI('http://purl.org/dc/elements/1.1/title'), 'Item 1')
    item_1.save!

    bytestream_1 = Bytestream.new(parent_url: item_1.repository_url,
                                  upload_pathname: File.expand_path('~/Pictures/Cars/f50.jpg'),
                                  requested_slug: 'bytestream1',
                                  item: item_1)
    bytestream_1.save!

    bytestream_2 = Bytestream.new(parent_url: item_1.repository_url,
                                  upload_pathname: File.expand_path('~/Pictures/Cars/f50.jpg'),
                                  requested_slug: 'bytestream2',
                                  item: item_1)
    bytestream_2.save!

    collection_1 = Collection.new(parent_url: @config.fedora_url,
                                  requested_slug: 'collection1',
                                  key: 'collection1')
    collection_1.rdf_graph << RDF::Statement.new(
        RDF::URI(), RDF::URI('http://purl.org/dc/elements/1.1/title'), 'Collection 1')
    collection_1.save!

    item_2 = Item.new(parent_url: collection_1.repository_url,
                      requested_slug: 'item2', collection: collection_1)
    item_2.rdf_graph << RDF::Statement.new(
        RDF::URI(), RDF::URI('http://purl.org/dc/elements/1.1/title'), 'Item 2')
    item_2.save!

    bytestream_3 = Bytestream.new(parent_url: item_2.repository_url,
                                  external_resource_url: 'https://www.google.com/',
                                  requested_slug: 'bytestream3', item: item_2)
    bytestream_3.save!

    item_3 = Item.new(parent_url: item_2.repository_url,
                      requested_slug: 'item3', collection: collection_1)
    item_3.rdf_graph << RDF::Statement.new(
        RDF::URI(), RDF::URI('http://purl.org/dc/elements/1.1/title'), 'Item 3')
    item_3.save!

    bytestream_4 = Bytestream.new(parent_url: item_3.repository_url,
                                  external_resource_url: 'https://www.google.com/',
                                  requested_slug: 'bytestream4', item: item_3)
    bytestream_4.save!

    item_1.save!
    item_2.save!
    item_3.save!
  end

  def teardown
    f4_url = @config.fedora_url
    urls_to_delete = ['/collection1', '/item1', '/item1/bytestream1',
                      '/item1/bytestream2', '/item2', '/item2/bytestream3',
                      '/item2/item3', '/item2/item3/bytestream4']
    urls_to_delete.each do |url|
      @http.delete(f4_url + url) rescue nil
      @http.delete(f4_url + url + '/fcr:tombstone') rescue nil
    end
  end

  private

  INDEXING_TRANSFORM_NAME = 'activemedusatest'

  def apply_indexing_transform
    body = "@prefix fcrepo : <http://fedora.info/definitions/v4/repository#>
    @prefix dc : <http://purl.org/dc/elements/1.1/>
    @prefix dcterms : <http://purl.org/dc/terms/>
    @prefix example : <http://example.org/>

    id = . :: xsd:string;
    uuid_s = fcrepo:uuid :: xsd:string;
    class_s = example:hasClass :: xsd:anyURI;
    collection_s = example:isMemberOf :: xsd:string;
    created_at_dts = fcrepo:created :: xsd:string;
    date_dts = example:date :: xsd:dateTime;
    full_text_txt = example:fullText :: xsd:string;
    page_index_i = example:pageIndex :: xsd:integer;
    parent_uri_s = example:parentURI :: xsd:anyURI;
    published_b = example:published :: xsd:boolean;
    updated_at_dts = fcrepo:lastModified :: xsd:string;
    title_s = fn:concat(dc:title,\"\",dcterms:title) :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_contributor_txt = dc:contributor :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_coverage_txt = dc:coverage :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_creator_txt = dc:creator :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_date_txt = dc:date :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_description_txt = dc:description :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_format_txt = dc:format :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_identifier_s = dc:identifier :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_language_txt = dc:language :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_publisher_txt = dc:publisher :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_relation_txt = dc:relation :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_rights_txt = dc:rights :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_source_txt = dc:source :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_subject_txt = dc:subject :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_title_txt = dc:title :: xsd:string;
    uri_http_purl_org_dc_elements_1_1_type_txt = dc:type :: xsd:string;
    uri_http_purl_org_dc_terms_abstract_txt = dcterms:abstract :: xsd:string;
    uri_http_purl_org_dc_terms_accessRights_txt = dcterms:accessRights :: xsd:string;
    uri_http_purl_org_dc_terms_accrualMethod_txt = dcterms:accrualMethod :: xsd:string;
    uri_http_purl_org_dc_terms_accrualPeriodicity_txt = dcterms:accrualPeriodicity :: xsd:string;
    uri_http_purl_org_dc_terms_accrualPolicy_txt = dcterms:accrualPolicy :: xsd:string;
    uri_http_purl_org_dc_terms_alternative_txt = dcterms:alternative :: xsd:string;
    uri_http_purl_org_dc_terms_audience_txt = dcterms:audience :: xsd:string;
    uri_http_purl_org_dc_terms_available_txt = dcterms:available :: xsd:string;
    uri_http_purl_org_dc_terms_bibliographicCitation_txt = dcterms:bibliographicCitation :: xsd:string;
    uri_http_purl_org_dc_terms_conformsTo_txt = dcterms:conformsTo :: xsd:string;
    uri_http_purl_org_dc_terms_contributor_txt = dcterms:contributor :: xsd:string;
    uri_http_purl_org_dc_terms_coverage_txt = dcterms:coverage :: xsd:string;
    uri_http_purl_org_dc_terms_created_txt = dcterms:created :: xsd:string;
    uri_http_purl_org_dc_terms_creator_txt = dcterms:creator :: xsd:string;
    uri_http_purl_org_dc_terms_date_txt = dcterms:date :: xsd:string;
    uri_http_purl_org_dc_terms_dateAccepted_txt = dcterms:dateAccepted :: xsd:string;
    uri_http_purl_org_dc_terms_dateCopyrighted_txt = dcterms:dateCopyrighted :: xsd:string;
    uri_http_purl_org_dc_terms_dateSubmitted_txt = dcterms:dateSubmitted :: xsd:string;
    uri_http_purl_org_dc_terms_description_txt = dcterms:description :: xsd:string;
    uri_http_purl_org_dc_terms_educationLevel_txt = dcterms:educationLevel :: xsd:string;
    uri_http_purl_org_dc_terms_extent_txt = dcterms:extent :: xsd:string;
    uri_http_purl_org_dc_terms_format_txt = dcterms:format :: xsd:string;
    uri_http_purl_org_dc_terms_hasFormat_txt = dcterms:hasFormat :: xsd:string;
    uri_http_purl_org_dc_terms_hasPart_txt = dcterms:hasPart :: xsd:string;
    uri_http_purl_org_dc_terms_hasVersion_txt = dcterms:hasVersion :: xsd:string;
    uri_http_purl_org_dc_terms_identifier_s = dcterms:identifier :: xsd:string;
    uri_http_purl_org_dc_terms_instructionalMethod_txt = dcterms:instructionalMethod :: xsd:string;
    uri_http_purl_org_dc_terms_isFormatOf_txt = dcterms:isFormatOf :: xsd:string;
    uri_http_purl_org_dc_terms_isPartOf_txt = dcterms:isPartOf :: xsd:string;
    uri_http_purl_org_dc_terms_isReferencedBy_txt = dcterms:isReferencedBy :: xsd:string;
    uri_http_purl_org_dc_terms_isReplacedBy_txt = dcterms:isReplacedBy :: xsd:string;
    uri_http_purl_org_dc_terms_isRequiredBy_txt = dcterms:isRequiredBy :: xsd:string;
    uri_http_purl_org_dc_terms_issued_txt = dcterms:issued :: xsd:string;
    uri_http_purl_org_dc_terms_isVersionOf_txt = dcterms:isVersionOf :: xsd:string;
    uri_http_purl_org_dc_terms_language_txt = dcterms:language :: xsd:string;
    uri_http_purl_org_dc_terms_license_txt = dcterms:license :: xsd:string;
    uri_http_purl_org_dc_terms_mediator_txt = dcterms:mediator :: xsd:string;
    uri_http_purl_org_dc_terms_MediaType_txt = dcterms:MediaType :: xsd:string;
    uri_http_purl_org_dc_terms_medium_txt = dcterms:medium :: xsd:string;
    uri_http_purl_org_dc_terms_modified_txt = dcterms:modified :: xsd:string;
    uri_http_purl_org_dc_terms_provenance_txt = dcterms:provenance :: xsd:string;
    uri_http_purl_org_dc_terms_publisher_txt = dcterms:publisher :: xsd:string;
    uri_http_purl_org_dc_terms_references_txt = dcterms:references :: xsd:string;
    uri_http_purl_org_dc_terms_relation_txt = dcterms:relation :: xsd:string;
    uri_http_purl_org_dc_terms_replaces_txt = dcterms:replaces :: xsd:string;
    uri_http_purl_org_dc_terms_requires_txt = dcterms:requires :: xsd:string;
    uri_http_purl_org_dc_terms_rights_txt = dcterms:rights :: xsd:string;
    uri_http_purl_org_dc_terms_rightsHolder_txt = dcterms:rightsHolder :: xsd:string;
    uri_http_purl_org_dc_terms_source_txt = dcterms:source :: xsd:string;
    uri_http_purl_org_dc_terms_spatial_txt = dcterms:spatial :: xsd:string;
    uri_http_purl_org_dc_terms_subject_txt = dcterms:subject :: xsd:string;
    uri_http_purl_org_dc_terms_tableOfContents_txt = dcterms:tableOfContents :: xsd:string;
    uri_http_purl_org_dc_terms_temporal_txt = dcterms:temporal :: xsd:string;
    uri_http_purl_org_dc_terms_title_txt = dcterms:title :: xsd:string;
    uri_http_purl_org_dc_terms_type_txt = dcterms:type :: xsd:string;
    uri_http_purl_org_dc_terms_valid_txt = dcterms:valid :: xsd:string;"
    url = "#{@config.fedora_url.chomp('/')}"\
    "/fedora:system/fedora:transform/fedora:ldpath/#{INDEXING_TRANSFORM_NAME}/fedora:Container"
    @http.put(url, body, { 'Content-Type' => 'application/rdf+ldpath' })
  end

end
