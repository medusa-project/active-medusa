require 'test_helper'

class SparqlUpdateTest < Minitest::Test

  def setup
    @update = ActiveMedusa::SPARQLUpdate.new
  end

  def test_to_s_should_assemble_a_correct_SPARQL_update
    expected = 'PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX indexing: <http://fedora.info/definitions/v4/indexing#>
DELETE WHERE { <> <http://example.org/webID> ?o };
DELETE WHERE { ?s <indexing:hasIndexingTransformation> ?o };
DELETE WHERE { <> <rdf:type> "indexing:Indexable" };
INSERT {
  ?s dc:title "some-resource-title" .
  <> <http://example.org/webID> <http://example.net/webid> .
  <> indexing:hasIndexingTransformation "kumquat" .
  <> rdf:type "indexing:Indexable" .
}
WHERE { }'
    @update.prefix('dc', 'http://purl.org/dc/elements/1.1/').
        prefix('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#').
        prefix('indexing', 'http://fedora.info/definitions/v4/indexing#').
        delete(nil, '<http://example.org/webID>', '?o', false).
        delete('?s', '<indexing:hasIndexingTransformation>', '?o', false).
        delete(nil, '<rdf:type>', 'indexing:Indexable').
        insert('?s', 'dc:title', 'some-resource-title').
        insert(nil, '<http://example.org/webID>', '<http://example.net/webid>', false).
        insert(nil, 'indexing:hasIndexingTransformation', 'kumquat').
        insert(nil, 'rdf:type', 'indexing:Indexable')
    assert_equal expected, @update.to_s
  end

end
