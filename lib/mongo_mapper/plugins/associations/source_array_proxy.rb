module MongoMapper
  module Plugins
    module Associations
      class SourceArrayProxy < Collection
        include ::MongoMapper::Finders

        def initialize(owner, reflection)
          super
          owner.class.class_eval do
            after_save :"save_#{reflection.name}_docs_that_do_or_did_reference_me"
            private
            define_method :"save_#{reflection.name}_docs_that_do_or_did_reference_me" do
              self.send(:"#{reflection.name}").save_referencing_docs
              self.send(:"#{reflection.name}").save_prior_referencing_docs
            end
          end
        end

        def find(*args)
          options = args.extract_options!

          case args.first
          when :first
            first(options)
          when :last
            last(options)
          when :all
            all(options)
          else
            klass.find(*args << scoped_options(options))
          end
        end

        def find!(*args)
          options = args.extract_options!

          case args.first
            when :first
              first(options)
            when :last
              last(options)
            when :all
              all(options)
            else
              klass.find!(*args << scoped_options(options))
          end
        end

        def all(options={})
          klass.all(scoped_options(options))
        end

        def first(options={})
          klass.first(scoped_options(options))
        end

        def last(options={})
          klass.last(scoped_options(options))
        end

        def count(options={})
          klass.count(scoped_options(options))
        end

        def destroy_all(options={})
          all(options).map(&:destroy)
          reset
        end

        def delete_all(options={})
          klass.delete_all(options.merge(scoped_conditions))
          reset
        end

        def nullify(options={})
          load_target
          target.each do |doc|
            doc[in_key].delete(owner.id)
            doc.save
          end
          reset
        end

        def paginate(options={})
          klass.paginate(scoped_options(options))
        end

        def create(attrs={})
          load_target
          owner.save if owner.new? # Because an owner id is required next
          (attrs[in_key] ||= []) << owner.id
          doc = klass.create(attrs)
          target << doc unless target.include?(doc) # So we have access to the new doc from our proxy object
          doc
        end

        def create!(attrs={})
          load_target
          owner.save if owner.new?
          (attrs[in_key] ||= []) << owner.id
          doc = klass.create!(attrs)
          target << doc unless target.include?(doc)
          doc
        end

        def <<(*docs)
          load_target
          flatten_deeper(docs).each do |doc|
            unless target.include?(doc)
              doc.send(options[:source]) << owner
              target << doc
            end
          end
        end
        alias_method :push, :<<
        alias_method :concat, :<<

        def replace(docs)
          load_target

          # Remove the owner from any docs about to be replaced
          @prior_referencing_docs ||= []
          target.each do |doc_with_in|
            # By removing the owner's id from any in_arrays
            doc_with_in.send(options[:source]).delete(owner)
            doc_with_in[in_key].delete(owner.id)
            @prior_referencing_docs << doc_with_in # To save later
          end

          # Add the owner to any replacement docs
          @new_referencing_docs ||= []
          docs.each do |doc_with_in|
            # Update each newly assigned docs in_array association to include this doc
            doc_with_in.send(options[:source]) << owner
            @new_referencing_docs << doc_with_in
          end
        end

        def save_referencing_docs
          @new_referencing_docs.each do |doc_referencing_me|
            doc_referencing_me.save
          end if @new_referencing_docs
        end

        def save_prior_referencing_docs
          @prior_referencing_docs.each do |doc_to_save_my_removal_from|
            doc_to_save_my_removal_from.save
          end if @prior_referencing_docs
        end

        private
        def scoped_conditions
          {in_key => owner._id}
        end

        # Same as in_array_proxy - factor code later
        def scoped_options(options)
          reflection.finder_options.merge(options).merge(scoped_conditions)
        end

        def find_target
          klass.all(in_key => owner.id)
        end

        def in_key
          klass.associations[options[:source]].options[:in]
        end

      end
    end
  end
end
