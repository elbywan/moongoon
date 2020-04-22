module Moongoon::Traits::Database::Methods::Get
  macro included
    @@aggregation_stages : Array(BSON)? = nil
    @@default_fields : BSON? = nil

    # Defines an [aggregation pipeline](https://docs.mongodb.com/v3.6/reference/operator/aggregation-pipeline/) that will be used instead of a plain find query.
    #
    # If this macro is used, the model will always use the [aggregate](https://docs.mongodb.com/v3.6/reference/command/aggregate/index.html)
    # method to query documents and will use the stages passed as arguments to aggregate the results.
    #
    # ```
    # aggregation_pipeline(
    #   {
    #     "$addFields": {
    #       count: {
    #         "$size": "$array"
    #       }
    #     }
    #   },
    #   {
    #     "$project": {
    #       array: 0
    #     }
    #   }
    # )
    # ```
    def self.aggregation_pipeline(*args)
      @@aggregation_stages = [] of BSON
      args.each { |arg|
        @@aggregation_stages.try { |a| a.<< arg.to_bson }
      }
    end

    # Set the `fields` value to use by default when calling `find` methods.
    #
    # ```
    # default_fields({ ignored_field: 0 })
    # ```
    def self.default_fields(fields)
      @@default_fields = fields.to_bson
    end

    # Finds one or multiple documents and returns an array of `Moongoon::Collection` instances.
    #
    # NOTE: Documents are sorted by creation date in descending order.
    #
    # ```
    # # Search for persons named Julien
    # users = User.find({ name: "Julien" })
    # ```
    #
    # It is possible to use optional arguments to order, paginate and control queries.
    #
    # ```
    # # Order the results by birth_date
    # users = User.find({ name: "Julien" }, order_by: { birth: 1 })
    #
    # # Paginate the results.
    # users = User.find({ name: "Julien" }, skip: 50, limit: 20)
    #
    # # Fetch only specific fields.
    # # Be extra careful to always fetch mandatory fields.
    # users = User.find({ name: "Julien" }, fields: { age: 1, name: 1 })
    # ```
    #
    # NOTE: Other arguments are available but will not be documented here.
    # For more details check out the underlying [`mongo.cr`](https://github.com/datanoise/mongo.cr)
    # driver documentation and code.
    def self.find(query = BSON.new, order_by = { _id: -1 }, fields = @@default_fields, skip = 0, limit = 0, **args) : Array(self)
      items = [] of self
      if stages = @@aggregation_stages
        pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(query, stages, fields, order_by, skip, limit)
        ::Moongoon.connection { |db|
          cursor = db[@@collection].aggregate(pipeline.to_bson, **args)
          while item = cursor.next
            items << self.new item
          end
        }
      else
        full_query = ::Moongoon::Traits::Database::Internal.format_query(query, order_by)
        bson_fields = (fields || BSON.new).to_bson
        ::Moongoon.connection { |db|
          cursor = db[@@collection].find(full_query.to_bson, **args, fields: bson_fields, skip: skip, limit: limit)
          while item = cursor.next
            items << self.new item
          end
        }
      end
      items
    end

    # NOTE: Similar to `self.find`, but raises when no documents are found.
    #
    # ```
    # begin
    #   users = User.find!({ name: "Julien" })
    # rescue
    #  raise "No one is named Julien."
    # end
    # ```
    def self.find!(query, **args) : Array(self)
      items = self.find(query, **args)
      unless items.size > 0
        query_json = query.to_json
        ::Moongoon::Log.info { "[mongo][find!](#{@@collection}) No matches for query:\n#{query_json}" }
        raise ::Moongoon::Error::NotFound.new
      end
      items
    end

    # Finds a single document and returns a `Moongoon::Collection` instance.
    #
    # ```
    # # Retrieve a single user named Julien
    # user = User.find_one({ name: "Julien" })
    # ```
    #
    # The following optional arguments are available.
    #
    # ```
    # # Fetch only specific fields.
    # # Be extra careful to always fetch mandatory fields.
    # user = User.find_one({ name: "Julien" }, fields: { age: 1, name: 1 })
    #
    # # Skip some results. Will return the 3rd user called Julien.
    # user = User.find_one({ name: "Julien"}, skip: 2)
    # ```
    #
    # NOTE: Other arguments are available but will not be documented here.
    # For more details check out the underlying [`mongo.cr`](https://github.com/datanoise/mongo.cr)
    # driver documentation and code.
    def self.find_one(query = BSON.new, fields = @@default_fields, order_by = { _id: -1 }, skip = 0, **args) : self?
      item = uninitialized BSON?
      if stages = @@aggregation_stages
        pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(query, stages, fields, order_by, skip)
        ::Moongoon.connection { |db|
          cursor = db[@@collection].aggregate(pipeline.to_bson,**args)
          item = cursor.next
        }
      else
        full_query = Moongoon::Traits::Database::Internal.format_query(query, order_by)
        bson_fields = (fields || BSON.new).to_bson
        item = ::Moongoon.connection { |db|
          db[@@collection].find_one(full_query.to_bson, **args, fields: bson_fields, skip: skip)
        }
      end
      self.new item if item
    end

    # NOTE: Similar to `self.find_one`, but raises when the document was not found.
    def self.find_one!(query, **args) : self
      item = self.find_one(query, **args)
      unless item
        query_json = query.to_json
        ::Moongoon::Log.info { "[mongo][find_one!](#{@@collection}) No matches for query:\n#{query_json}" }
        raise ::Moongoon::Error::NotFound.new
      end
      item
    end

    # Finds a single document by id and returns a `Moongoon::Collection` instance.
    #
    # Syntax is similar to `self.find_one`.
    #
    # ```
    # user = User.find_by_id(123456)
    # ```
    def self.find_by_id(id : String, query = BSON.new, order_by = { _id: -1 }, fields = @@default_fields, **args) : self?
      item = uninitialized BSON?
      query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_id_filter id)
      if stages = @@aggregation_stages
        pipeline = ::Moongoon::Traits::Database::Internal.format_aggregation(query, stages, fields, order_by)
        ::Moongoon.connection { |db|
          cursor = db[@@collection].aggregate(pipeline.to_bson, **args)
          item = cursor.next
        }
      else
        full_query = ::Moongoon::Traits::Database::Internal.format_query(query, order_by)
        bson_fields = (fields || BSON.new).to_bson
        item = ::Moongoon.connection { |db|
          db[@@collection].find_one(full_query.to_bson, **args, fields: bson_fields, skip: 0)
        }
      end
      self.new item if item
    end

    # NOTE: Similar to `self.find_by_id`, but raises when the document was not found.
    def self.find_by_id!(id, **args) : self
      item = self.find_by_id(id, **args)
      unless item
        ::Moongoon::Log.info { "[mongo][find_by_id!](#{@@collection}) Failed to fetch resource with id #{id}." }
        raise ::Moongoon::Error::NotFound.new
      end
      item.not_nil!
    end

    # Finds one or multiple documents by their ids and returns an array of `Moongoon::Collection` instances.
    #
    # Syntax is similar to `self.find`.
    #
    # ```
    # ids = ["1", "2", "3"]
    # users = User.find_by_ids(ids)
    # ```
    def self.find_by_ids(ids, query = BSON.new, order_by = { _id: -1 }, **args) : Array(self)?
      query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_ids_filter ids)
      self.find(query, order_by, **args)
    end

    # NOTE: Similar to `self.find_by_ids`, but raises when no documents are found.
    def self.find_by_ids!(ids, **args) : Array(self)?
      items = self.find_by_ids(ids, **args)
      unless items.size > 0
        ::Moongoon::Log.info { "[mongo][exists!](#{@@collection}) No matches for ids #{ids.to_json}." }
        raise ::Moongoon::Error::NotFound.new
      end
      items
    end

    # Finds ids for documents matching the *query* argument and returns them an array of strings.
    #
    # Syntax is similar to `self.find`.
    #
    # ```
    # jane_ids = User.find_ids({ name: "Jane" })
    # ```
    def self.find_ids(query = BSON.new, order_by = { _id: -1 }, **args) : Array(String)
      ids = [] of String
      full_query = ::Moongoon::Traits::Database::Internal.format_query(query, order_by)
      ::Moongoon.connection { |db|
        cursor = db[@@collection].find(full_query.to_bson, **args, fields: { _id: 1 }.to_bson)
        while item = cursor.next
          ids << item["_id"].as(BSON::ObjectId).to_s
        end
      }
      ids
    end

    # Counts the number of documents in the collection for a given query.
    #
    # ```
    # count = User.count({ name: "Julien" })
    # ```
    def self.count(query = BSON.new, **args) : Int32 | Int64
      count = 0
      ::Moongoon.connection { |db|
        count = db[@@collection].count(query.to_bson, **args)
        nil
      }
      count
    end

    # Ensures that at least one document matches the query.
    # Will raise when there is no match.
    #
    # ```
    # begin
    #   User.exist!({ name: "Julien" })
    # rescue e : Moongoon::Error::NotFound
    #   # No user named Julien found
    # end
    # ```
    def self.exist!(query = BSON.new, **args) : Bool
      count = self.count query, **args
      unless count > 0
        query_json = query.to_json
        ::Moongoon::Log.info { "[mongo][exists!](#{@@collection}) No matches for query:\n#{query_json}" }
        raise ::Moongoon::Error::NotFound.new
      end
      count > 0
    end

    # Same as `self.exist!` but for a single document given its id.
    #
    # ```
    # begin
    #   User.exist_by_id!("123456")
    # rescue e : Moongoon::Error::NotFound
    #   # No user having _id "123456" found
    # end
    # ```
    def self.exist_by_id!(id, query = BSON.new, **args) : Bool
      query = query.to_bson.clone.concat(Moongoon::Traits::Database::Internal.build_id_filter id)
      self.exist! query, **args
    end
  end
end
