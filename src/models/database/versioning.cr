# :nodoc:
module Moongoon::Traits::Database::Versioning
  macro included
  {% verbatim do %}
    # Enable versioning for this collection.
    #
    # Manages a history in separate mongo collection and adds query methods.
    # The name of the versioning collection is equal to the name of the base
    # collection with a "_history" suffix appended.
    #
    # NOTE: Documents in the history collection will follow the same data model as
    # the base documents, except for an extra field that will contain a back
    # reference to the base document id.
    #
    # **Arguments**
    #
    # - *ref_field*: The name of the reference field that will point to the original document.
    # Defaults to the name of the Class in pascal_case with an "_id" suffix appended.
    # - *create_index*: if set to true, will create an index on the reference field in the history collection.
    # - *auto*: if the auto flag is true, every insertion and update will be recorded.
    # Without the auto flag, a version will only be created programatically when calling
    # the `create_version` methods.
    # - *transform*: a block that will be executed to transform the BSON document before insertion.
    #
    # ```
    # class MyModel < Moongoon::Collection
    #   include Versioning
    #
    #   collection "my_model"
    #   versioning auto: true
    # end
    # ```
    macro versioning(*, ref_field = nil, auto = false, create_index = false, &transform)
      {% if ref_field %}
        @@versioning_id_field = {{ref_field.id.stringify}}
      {% end %}

      {% if transform %}
        @@versioning_transform = Proc(BSON, BSON, BSON).new {{transform}}
      {% end %}

      {% if create_index %}
        index({
          @@versioning_id_field => 1
        }, "#{@@collection_name}_history")
      {% end %}

      {% if auto %}
      # After an insertion, copy the document in the history collection.
      after_insert { |model|
        db = {{@type}}.database
        collection = {{@type}}.collection
        history_collection = {{@type}}.history_collection

        data = collection.find_one({_id: model._id })

        if data
          updated_data = BSON.new
          data.each { |k, v|
            if k == "_id"
              updated_data[k] = BSON::ObjectId.new
            else
              updated_data[k] = v
            end
          }
          @@versioning_transform.try { |cb|
            updated_data = cb.call(updated_data, data)
          }
          updated_data[@@versioning_id_field] = data["_id"].to_s
          history_collection.insert_one(updated_data)
        end
      }

      # After an update, copy the updated document in the history collection.
      after_update { |model|
        db = {{@type}}.database
        collection = {{@type}}.collection
        history_collection = {{@type}}.history_collection

        data = collection.find_one({_id: model._id })

        if data
          updated_data = BSON.new
          data.each { |k, v|
            if k == "_id"
              updated_data[k] = BSON::ObjectId.new
            else
              updated_data[k] = v
            end
          }
          @@versioning_transform.try { |cb|
            updated_data = cb.call(updated_data, data)
          }
          updated_data[@@versioning_id_field] = data["_id"].to_s
          history_collection.insert_one(updated_data)
        end
      }

      # After a static update, copy the document(s) in the history collection.
      after_update_static { |query, _|
        db = {{@type}}.database
        collection = {{@type}}.collection
        history_collection = {{@type}}.history_collection

        cursor = collection.find(query)
        bulk = history_collection.bulk(ordered: true)
        cursor.each do |model|
          updated_model = BSON.new
          model.each { |k, v|
            if k == "_id"
              updated_model[k] = BSON::ObjectId.new
            else
              updated_model[k] = v
            end
          }
          @@versioning_transform.try { |cb|
            updated_model = cb.call(updated_model, model)
          }
          updated_model[@@versioning_id_field] = model["_id"].to_s
          bulk.insert_one(updated_model)
        end
        bulk.execute
        nil
      }
      {% end %}
    end

    # Finds the latest version of a model and returns an instance of `Moongoon::Collection`.
    #
    # Same syntax as `Moongoon::Collection#find_by_id`, except that specifying the id is not needed.
    #
    # ```
    # user = User.new
    # user.id = "123456"
    # user_version = user.find_latest_version
    # ```
    def find_latest_version(**args) : self?
      id_check!
      self.class.find_latest_version_by_id(self.id, **args)
    end

    # Finds all versions of the model and returns an array of `Moongoon::Collection` instances.
    #
    # NOTE: Versions are sorted by creation date.
    #
    # ```
    # user = User.new name: "Jane"
    # user.insert
    # user.create_version
    # versions = user.find_all_versions
    # ```
    def find_all_versions(**args) : Array(self)
      id_check!
      self.class.find_all_versions(self.id, **args)
    end

    # Counts the number of versions associated with this model.
    #
    # ```
    # user = User.new name: "Jane"
    # user.insert
    # user.create_version
    # nb_of_versions = User.count_versions user
    # ```
    def count_versions(**args) : Int32 | Int64
      self.class.count_versions(self.id, **args)
    end

    # Saves a copy of the model in the history collection and returns the id of the copy.
    #
    # NOTE: Does not use the model data but reads the latest version from the database before copying.
    #
    # ```
    # user = User.new name: "Jane"
    # user.insert
    # user.create_version
    # ```
    def create_version : String?
      self.class.create_version_by_id(self.id!)
    end

    # Saves a copy with changes of the model in the history collection and
    # returns the id of the copy.
    #
    # The *block* argument can be used to alter the model before insertion.
    #
    # ```
    # user = User.new name: "Jane", age: 20
    # user.insert
    # user.create_version &.tap { |data|
    #   # "data" is the model representation of the document that gets copied.
    #   data.key = data.key + 1
    # }
    # ```
    def create_version(&block : self -> self) : String?
      self.class.create_version_by_id self.id!, &block
    end

    module Static
      # Finds the latest version of a model by id and returns an instance of `Moongoon::Collection`.
      #
      # Same syntax as `Moongoon::Collection.find_by_id`.
      #
      # ```
      # # "123456" is an _id in the original collection.
      # user_version = user.find_latest_version_by_id "123456"
      # ```
      def find_latest_version_by_id(id, fields = nil, **args) : self?
        history_collection = self.history_collection
        query = {@@versioning_id_field => id}
        order_by = {_id: -1}

        item = if stages = @@aggregation_stages
          pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(query, stages, fields, limit: 1)
          cursor = history_collection.aggregate(pipeline, **args)
          cursor.try &.first?
        else
          history_collection.find_one(query, **args, sort: order_by, skip: 0, projection: fields)
        end
        self.new item if item
      end

      # Finds a specific version of a model by id and returns an instance of `Moongoon::Collection`.
      #
      # Same syntax as `Moongoon::Collection.find_by_id`.
      #
      # ```
      # # "123456" is an _id in the history collection.
      # user_version = user.find_specific_version "123456"
      # ```
      def find_specific_version(id, query = BSON.new, fields = nil, skip = 0, **args) : self?
        history_collection = self.history_collection
        full_query = ::Moongoon::Traits::Database::Internal.concat_id_filter(query, id)

        item = if stages = @@aggregation_stages
          pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(full_query, stages, fields, skip: skip)
          cursor = history_collection.aggregate(pipeline, **args)
          cursor.try &.first?
        else
          history_collection.find_one(full_query, **args, projection: fields, skip: skip)
        end
        self.new item if item
      end

      # NOTE: Similar to `self.find_specific_version` but will raise if the version is not found.
      def find_specific_version!(id, **args) : self
        item = find_specific_version(id, **args)
        unless item
          ::Moongoon::Log.info { "[mongo][find_specific_version](#{self.collection_name}) Failed to fetch resource with id #{id}." }
          raise ::Moongoon::Error::NotFound.new
        end
        item
      end

      # Finds one or more versions by their ids and returns an array of `Moongoon::Collection` instances.
      #
      # NOTE: Versions are sorted by creation date in descending order.
      #
      # ```
      # names = ["John", "Jane"]
      # ids = names.map { |name|
      #   user = User.new name: name
      #   user.insert
      #   user.create_version
      # }
      # # Contains one version for both models.
      # versions = User.find_specific_versions ids
      # ```
      def find_specific_versions(ids, query = BSON.new, fields = nil, skip = 0, limit = 0,  order_by = {_id: -1}, **args) : Array(self)
        items = [] of self
        history_collection = self.history_collection
        query = ::Moongoon::Traits::Database::Internal.concat_ids_filter(query, ids)

        if stages = @@aggregation_stages
          pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(query, stages, fields, order_by, skip, limit)
          cursor = history_collection.aggregate(pipeline, **args)
          cursor.try { |c| items = c.map{|b| self.from_bson b}.to_a }
        else
          cursor = history_collection.find(query, **args, sort: order_by, projection: fields)
          items = cursor.map{|b| self.from_bson b}.to_a
        end

        items
      end

      # Finds all versions for a document matching has the *id* argument and returns an array of `Moongoon::Collection` instances.
      #
      # NOTE: Versions are sorted by creation date.
      #
      # ```
      # user_id = "123456"
      # versions = User.find_all_versions user_id
      # ```
      def find_all_versions(id, query = BSON.new, fields = nil, skip = 0, limit = 0, order_by = {_id: -1}, **args) : Array(self)
        items = [] of self
        history_collection = self.history_collection
        query = BSON.new({@@versioning_id_field => id}).append(BSON.new(query))

        if stages = @@aggregation_stages
          pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(query, stages, fields, order_by, skip, limit)
          cursor = history_collection.aggregate(pipeline, **args)
          cursor.try { |c| items = c.map{|b| self.from_bson b}.to_a }
        else
          cursor = history_collection.find(query, **args, sort: order_by, projection: fields)
          items = cursor.map{|b| self.from_bson b}.to_a
        end

        items
      end

      # Counts the number of versions associated with a document that matches the *id* argument.
      #
      # ```
      # user_id = "123456"
      # User.count_versions user_id
      # ```
      def count_versions(id, query = BSON.new, **args) : Int32 | Int64
        history_collection = self.history_collection
        query = BSON.new({@@versioning_id_field => id}).append(BSON.new(query))
        history_collection.count_documents(query, **args)
      end

      # Clears the history collection.
      #
      # NOTE: **Use with caution!**
      #
      # Will remove all the versions in the history collection.
      def clear_history : Nil
        self.history_collection.delete_many(BSON.new)
      end

      # Saves a copy of a document matching the *id* argument in the history
      # collection and returns the id of the copy.
      #
      # NOTE: similar to `create_version`.
      def create_version_by_id(id) : String?
        self.create_version_by_id(id) { |data| data }
      end

      # Saves a copy with changes of a document matching the *id* argument
      # in the history collection and returns the id of the copy.
      #
      # NOTE: similar to `create_version`.
      def create_version_by_id(id, &block : self -> self) : String?
        version_id : String? = nil
        original = self.find_by_id id
        history_collection = self.history_collection

        if original
          oid = BSON::ObjectId.new
          original_bson = original.to_bson
          original_oid = original._id
          version_id = oid.to_s
          original._id = oid
          original = yield original
          version_bson = original.to_bson
          updated_model = @@versioning_transform.try { |cb| version_bson = cb.call(version_bson, original_bson) }
          version_bson[@@versioning_id_field] = original_oid.to_s
          history_collection.insert_one(version_bson)
        end

        version_id
      end
    end
  {% end %}
  end
end
