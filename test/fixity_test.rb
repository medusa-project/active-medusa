require_relative 'test_helper'

class FixityTest < Minitest::Test

  def test_from_graph_with_fixity_success
    ttl = '<http://localhost:8080/rest/path/to/some/resource#fixity/1400589459772> a <http://www.loc.gov/premis/rdf/v1#Fixity> .
<http://localhost:8080/rest/path/to/some/resource> <http://www.loc.gov/premis/rdf/v1#hasFixity> <http://localhost:8080/rest/path/to/some/resource#fixity/1400589459772> .
<http://localhost:8080/rest/path/to/some/resource#fixity/1400589459772> <http://www.loc.gov/premis/rdf/v1#hasContentLocation> <info://org.modeshape.jcr.value.binary.FileSystemBinaryStore@7bcc39fb/fcrepo4/fcrepo-webapp/fcrepo4-data/fcrepo.binary.directory#f7d787ee7fc58ce7fc257ae0067a2c65476be750> .
<info://org.modeshape.jcr.value.binary.FileSystemBinaryStore@7bcc39fb/fcrepo4/fcrepo-webapp/fcrepo4-data/fcrepo.binary.directory#f7d787ee7fc58ce7fc257ae0067a2c65476be750> a <http://www.loc.gov/premis/rdf/v1#ContentLocation> ;
<http://www.loc.gov/premis/rdf/v1#hasContentLocationValue> "info://org.modeshape.jcr.value.binary.FileSystemBinaryStore@7bcc39fb/fcrepo4/fcrepo-webapp/fcrepo4-data/fcrepo.binary.directory#f7d787ee7fc58ce7fc257ae0067a2c65476be750"^^<http://www.w3.org/2001/XMLSchema#string> .'
    graph = RDF::Graph.new
    graph.from_ttl(ttl)

    fixity = ActiveMedusa::Fixity.from_graph(graph)
    assert_equal 'info://org.modeshape.jcr.value.binary.FileSystemBinaryStore@7bcc39fb/fcrepo4/fcrepo-webapp/fcrepo4-data/fcrepo.binary.directory#f7d787ee7fc58ce7fc257ae0067a2c65476be750', fixity.content_location
    assert_equal 'http://localhost:8080/rest/path/to/some/resource#fixity/1400589459772',
                 fixity.repository_url
    assert_nil fixity.size
    assert_nil fixity.digest
    assert_equal 1, fixity.statuses.length
    assert_equal ActiveMedusa::Fixity::Status::OK, fixity.statuses.first
  end

  def test_from_graph_with_fixity_failure
    ttl = '<http://localhost:8080/rest/path/to/some/resource#fixity/1400589459772> a <http://www.loc.gov/premis/rdf/v1#Fixity> .
<http://localhost:8080/rest/path/to/some/resource> <http://www.loc.gov/premis/rdf/v1#hasFixity> <http://localhost:8080/rest/path/to/some/resource#fixity/1400589459772> .
<http://localhost:8080/rest/path/to/some/resource#fixity/1400589459772> <http://www.loc.gov/premis/rdf/v1#hasContentLocation> <info://org.modeshape.jcr.value.binary.FileSystemBinaryStore@7bcc39fb/fcrepo4/fcrepo-webapp/fcrepo4-data/fcrepo.binary.directory#f7d787ee7fc58ce7fc257ae0067a2c65476be750> .
<http://localhost:8080/rest/path/to/some/resource#fixity/1400589459772> <http://fedora.info/definitions/v4/repository#status> "BAD_CHECKSUM"^^<http://www.w3.org/2001/XMLSchema#string> , "BAD_SIZE"^^<http://www.w3.org/2001/XMLSchema#string> ;
<http://www.loc.gov/premis/rdf/v1#hasMessageDigest> <urn:sha1:b04bded0d83b74ac0c700945e24e43e823eb5821> ;
<http://www.loc.gov/premis/rdf/v1#hasSize> "1324943"^^<http://www.w3.org/2001/XMLSchema#int> .'
    graph = RDF::Graph.new
    graph.from_ttl(ttl)

    graph.each_statement do |st|
      puts "#{st.subject} #{st.predicate} #{st.object}"
    end

    fixity = ActiveMedusa::Fixity.from_graph(graph)
    assert_nil fixity.content_location
    assert_equal 'http://localhost:8080/rest/path/to/some/resource#fixity/1400589459772',
                 fixity.repository_url
    assert_equal 1324943, fixity.size
    assert_equal 'urn:sha1:b04bded0d83b74ac0c700945e24e43e823eb5821', fixity.digest
    assert_equal 2, fixity.statuses.length
    statuses = fixity.statuses.sort
    assert_equal ActiveMedusa::Fixity::Status::BAD_CHECKSUM, statuses.first
    assert_equal ActiveMedusa::Fixity::Status::BAD_SIZE, statuses.second
  end

end
