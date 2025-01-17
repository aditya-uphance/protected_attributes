module ActiveRecord
  module Associations
    class Association
      undef :build_record

      def build_record(attributes)
        reflection.build_association(attributes) do |record|
          attributes = create_scope.except(*(record.changed - [reflection.foreign_key]))
          record.assign_attributes(attributes, without_protection: true)
        end
      end

      private :build_record
    end

    class CollectionAssociation
      undef :build
      undef :create
      undef :create!

      def build(attributes = {}, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          add_to_target(build_record(attributes)) do |record|
            yield(record) if block_given?
          end
        end
      end

      def create(attributes = {}, &block)
        create_record(attributes, &block)
      end

      def create!(attributes = {}, &block)
        create_record(attributes, true, &block)
      end

      def create_record(attributes, raise = false, &block)
        unless owner.persisted?
          raise ActiveRecord::RecordNotSaved, "You cannot call create unless the parent is saved"
        end

        if attributes.is_a?(Array)
          attributes.collect { |attr| create_record(attr, raise, &block) }
        else
          transaction do
            add_to_target(build_record(attributes)) do |record|
              yield(record) if block_given?
              insert_record(record, true, raise)
            end
          end
        end
      end

      private :create_record
    end

    class CollectionProxy
      undef :create
      undef :create!

      def build(attributes = {}, &block)
        @association.build(attributes, &block)
      end
      alias_method :new, :build

      def create(attributes = {}, &block)
        @association.create(attributes, &block)
      end

      def create!(attributes = {}, &block)
        @association.create!(attributes, &block)
      end
    end

    module ThroughAssociation
      undef :build_record if respond_to?(:build_record, false)

      private

        def build_record(attributes)
          inverse = source_reflection.inverse_of
          target = through_association.target

          if inverse && target && !target.is_a?(Array)
            attributes[inverse.foreign_key] = target.id
          end

          super(attributes)
        end
    end

    class HasManyThroughAssociation
      undef :build_record
      undef :options_for_through_record if respond_to?(:options_for_through_record, false)

      def build_record(attributes)
        ensure_not_nested

        record = super(attributes)

        inverse = source_reflection.inverse_of
        if inverse
          if inverse.macro == :has_many
            record.send(inverse.name) << build_through_record(record)
          elsif inverse.macro == :has_one
            record.send("#{inverse.name}=", build_through_record(record))
          end
        end

        record
      end
      private :build_record

      def options_for_through_record
        [through_scope_attributes, without_protection: true]
      end
      private :options_for_through_record
    end

    class SingularAssociation
      undef :create
      undef :create!
      undef :build

      def create(attributes = {}, &block)
        create_record(attributes, &block)
      end

      def create!(attributes = {}, &block)
        create_record(attributes, true, &block)
      end

      def build(attributes = {})
        record = build_record(attributes)
        yield(record) if block_given?
        set_new_record(record)
        record
      end

      def create_record(attributes, raise_error = false)
        record = build_record(attributes)
        yield(record) if block_given?
        saved = record.save
        set_new_record(record)
        raise RecordInvalid.new(record) if !saved && raise_error
        record
      end

      private :create_record
    end
  end
end
