module ActiveMedusa

  ##
  # Concern that can be included by ActiveMedusa entities to help them update
  # Solr using ActiveRecord callbacks.
  #
  # `reindex_in_solr()` will create or update a Solr document representing the
  # entity. By default, it will include 1) all fields required by ActiveMedusa;
  # 2) all entity properties defined with `property` statements; and 3) all
  # belongs-to associations. Additional fields can be added by overriding
  # `solr_document`:
  #
  #     class MyEntity < ActiveMedusa::Container
  #       include ActiveMedusa::Indexable
  #
  #       # overrides the version in Indexable
  #       def solr_document
  #         doc = super
  #         doc['new_solr_field'] = 'something else' # add a field
  #         doc
  #       end
  #     end
  #
  module Indexable

    extend ActiveSupport::Concern

    included do
      after_save :reindex_in_solr
      after_destroy :delete_from_solr
    end

    def delete_from_solr
      Solr.client.delete_by_id(self.repository_url) if self.destroyed?
    end

    def reindex_in_solr
      Solr.client.add(solr_document)
    end

    ##
    # Returns a Solr document structure as a hash suitable for passing to
    # `RSolr.add()`. It will contain the bare minimum amount of information
    # necessary to work with ActiveMedusa.
    #
    # @return [Hash<String,String>]
    #
    def solr_document
      config = Configuration.instance

      # add fields required by activemedusa
      doc = {
          config.solr_uuid_field => self.uuid,
          config.solr_id_field => self.id,
          config.solr_class_field => self.class.entity_class_uri,
          config.solr_parent_uri_field =>
              self.rdf_graph.any_object('http://fedora.info/definitions/v4/repository#hasParent').to_s,
      }

      # add fields corresponding to property statements
      self.class.properties.select{ |p| p.class == self.class }.each do |prop|
        doc[prop.solr_field] = self.send(prop.name)
      end

      # add fields corresponding to associations
      self.class.associations.
          select{ |a| a.source_class == self.class and
          a.type == Association::Type::BELONGS_TO }.each do |assoc|
        obj = self.send(assoc.name)
        doc[assoc.solr_field] = obj.repository_url if
            obj.respond_to?(:repository_url)
      end

      doc
    end

  end

end
