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
    # - *id_field*: The name of the back reference field. By default, the name
    # of the Class in pascal_case and with an "_id" suffix appended.
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
    macro versioning(id_field = nil, auto = false, &transform)
      {% if id_field %}
        @@versioning_id_field = {{id_field.stringify}}
      {% end %}

      {% if transform %}
        @@versioning_transform = Proc(BSON, BSON, BSON).new {{transform}}
      {% end %}

      {% if auto %}
      # After an insertion, copy the document in the history collection.
      after_insert { |model|
        data = ::Moongoon.connection { |db|
          db[@@collection].find_one({_id: model._id.not_nil!}.to_bson)
        }
        if data
          updated_data = BSON.new
          data.each_key { |k|
            if k == "_id"
              updated_data[k] = BSON::ObjectId.new
            else
              updated_data[k] = data[k]
            end
          }
          @@versioning_transform.try { |cb| updated_data = cb.call(updated_data, data) }
          updated_data[@@versioning_id_field] = data["_id"].to_s
          ::Moongoon.connection { |db|
            db["#{@@collection}_history"].insert(updated_data)
          }
        end
      }

      # After an update, copy the updated document in the history collection.
      after_update { |model|
        data = ::Moongoon.connection { |db|
         db[@@collection].find_one({_id: model._id.not_nil!}.to_bson)
        }
        if data
          updated_data = BSON.new
          data.each_key { |k|
            if k == "_id"
              updated_data[k] = BSON::ObjectId.new
            else
              updated_data[k] = data[k]
            end
          }
          @@versioning_transform.try { |cb| cb.call(updated_data, data) }
          updated_data[@@versioning_id_field] = data["_id"].to_s
          ::Moongoon.connection { |db|
            db["#{@@collection}_history"].insert(updated_data)
          }
        end
      }

      # After a static update, copy the document(s) in the history collection.
      after_update_static { |query, _|
        ::Moongoon.connection { |db|
          collection = db["#{@@collection}_history"]
          data = db[@@collection].find query
          bo = collection.create_bulk_operation
          empty_data = true
          data.each do |datum|
            updated_datum = BSON.new
            datum.each_key { |k|
              empty_data = false
              if k == "_id"
                updated_datum[k] = BSON::ObjectId.new
              else
                updated_datum[k] = datum[k]
              end
            }
            @@versioning_transform.try { |cb| cb.call(updated_datum, data) }
            updated_datum[@@versioning_id_field] = datum["_id"].to_s
            bo.insert(updated_datum)
          end
          bo.execute unless empty_data
        }
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
      {{ @type }}.find_latest_version_by_id(self.id, **args)
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
      {{@type}}.find_all_versions(self.id)
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
      {{@type}}.count_versions(self.id)
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
      {{@type}}.create_version_by_id(self.id!)
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
      {{@type}}.create_version_by_id self.id!, &block
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
        query = {@@versioning_id_field => id}
        order_by = {_id: -1}
        if stages = @@aggregation_stages
          pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(query, stages, fields, limit: 1)
          ::Moongoon.connection { |db|
            cursor = db["#{@@collection}_history"].aggregate(pipeline.to_bson, **args)
            cursor.next
          }
        else
          full_query = ::Moongoon::Traits::Database::Internal.format_query(query, order_by)
          bson_fields = (fields || BSON.new).to_bson
          item = ::Moongoon.connection { |db|
            cursor = db["#{@@collection}_history"].find(full_query.to_bson, **args, limit: 1, skip: 0, fields: bson_fields)
            cursor.next
          }
        end
        {{@type}}.new item if item
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
        full_query = query.to_bson.clone.concat({_id: BSON::ObjectId.new id}.to_bson)
        if stages = @@aggregation_stages
          pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(full_query, stages, fields, limit: 1, skip: skip)
          ::Moongoon.connection { |db|
            cursor = db["#{@@collection}_history"].aggregate(pipeline.to_bson, **args)
            cursor.next
          }
        else
          bson_fields = (fields || BSON.new).to_bson
          item = ::Moongoon.connection { |db|
            db["#{@@collection}_history"].find_one(full_query.to_bson, **args, fields: bson_fields, skip: skip)
          }
        end
        {{@type}}.new item if item
      end

      # NOTE: Similar to `self.find_specific_version` but will raise if the version is not found.
      def find_specific_version!(id, **args) : self
        item = find_specific_version(id, **args)
        unless item
          ::Moongoon::Log.info { "[mongo][find_specific_version](#{@@collection}) Failed to fetch resource with id #{id}." }
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
      def find_specific_versions(ids, query = BSON.new, fields = nil, skip = 0, limit = 0, **args) : Array(self)
        items = [] of self
        query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_ids_filter ids)
        order_by = {_id: -1}
        if stages = @@aggregation_stages
          pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(query, stages, fields, order_by, skip, limit)
          ::Moongoon.connection { |db|
            cursor = db["#{@@collection}_history"].aggregate(pipeline.to_bson, **args)
            while item = cursor.next
              items << {{@type}}.new item
            end
          }
        else
          full_query = ::Moongoon::Traits::Database::Internal.format_query(query, order_by)
          bson_fields = (fields || BSON.new).to_bson
          ::Moongoon.connection { |db|
            cursor = db["#{@@collection}_history"].find(full_query.to_bson, **args, fields: bson_fields)
            while item = cursor.next
              items << {{@type}}.new item
            end
          }
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
      def find_all_versions(id, query = BSON.new, fields = nil, skip = 0, limit = 0, **args) : Array(self)
        items = [] of self
        query = query.to_bson.clone.concat({@@versioning_id_field => id}.to_bson)
        order_by = {_id: -1}
        if stages = @@aggregation_stages
          pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(query, stages, fields, order_by, skip, limit)
          ::Moongoon.connection { |db|
            cursor = db["#{@@collection}_history"].aggregate(pipeline.to_bson, **args)
            while item = cursor.next
              items << {{@type}}.new item
            end
          }
        else
          full_query = ::Moongoon::Traits::Database::Internal.format_query(query, order_by)
          bson_fields = (fields || BSON.new).to_bson
          ::Moongoon.connection { |db|
            cursor = db["#{@@collection}_history"].find(full_query.to_bson, **args, fields: bson_fields)
            while item = cursor.next
              items << {{@type}}.new item
            end
          }
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
        count = 0
        ::Moongoon.connection { |db|
          query = query.to_bson.clone.concat({@@versioning_id_field => id}.to_bson)
          count = db["#{@@collection}_history"].count(query.to_bson, **args)
          nil
        }
        count
      end

      # Clears the history collection.
      #
      # NOTE: **Use with caution!**
      #
      # Will remove all the versions in the history collection.
      def clear_history : Nil
        ::Moongoon.connection { |db|
          db["#{@@collection}_history"].remove(({} of String => BSON).to_bson)
        }
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

        if original
          oid = BSON::ObjectId.new
          original_bson = original.to_bson
          original_oid = original._id
          version_id = oid.to_s
          original._id = oid
          original = yield original
          version_bson = original.to_bson
          @@versioning_transform.try { |cb| version_bson = cb.call(version_bson, original_bson) }
          version_bson[@@versioning_id_field] = original_oid.to_s
          ::Moongoon.connection { |db|
            db["#{@@collection}_history"].insert(version_bson)
          }
        end

        version_id
      end
    end
  {% end %}
  end
end
