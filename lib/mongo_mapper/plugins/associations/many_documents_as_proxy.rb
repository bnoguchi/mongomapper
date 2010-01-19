module MongoMapper
  module Plugins
    module Associations
      class ManyDocumentsAsProxy < ManyDocumentsProxy
				def build(attrs={})
					doc = klass.new(attrs)
					if owner.new?
						doc[type_key_name] = owner.class.name
						(@docs_to_add_foreign_id_to_later ||= []) << doc
					else
						apply_scope(doc)
					end
					doc
				end

				def assign_foreign_id_and_save_built_docs
					(@docs_to_add_foreign_id_to_later || []).each do |doc|
						apply_scope(doc).save if doc.new? && doc[id_key_name].nil?
					end
				end

        protected
          def scoped_conditions
            {type_key_name => owner.class.name, id_key_name => owner.id}
          end

          def apply_scope(doc)
            ensure_owner_saved
            doc[type_key_name] = owner.class.name
            doc[id_key_name] = owner.id
            doc
          end

        private
          def type_key_name
            "#{options[:as]}_type"
          end

          def id_key_name
            "#{options[:as]}_id"
          end
      end
    end
  end
end
