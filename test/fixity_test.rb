require_relative 'test_helper'

class FixityTest < Minitest::Test

  def test_from_graph
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
  end

end
