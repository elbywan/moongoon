# :nodoc:
module Moongoon::Traits::Database::Indexes
  extend self

  @@indexes = Array({BSON, Proc(Tuple(String, String))}).new

  # :nodoc:
  def add_index(index : BSON, callback : Proc(Tuple(String, String)))
    @@indexes << { index, callback }
  end

  ::Moongoon.after_connect do

    index_hash = Hash(String, Hash(String, Array(BSON))).new

    @@indexes.each { |index, cb|
      database, collection = cb.call
      index_hash[database] = Hash(String, Array(BSON)).new unless index_hash[database]?
      index_hash[database][collection] = Array(BSON).new unless index_hash[database][collection]?
      index_hash[database][collection] << index
    }

    index_hash.each { |database, coll_hash|
      coll_hash.each { |collection, indexes|
        begin
          ::Moongoon.connection_with_lock "indexes_#{database}_#{collection}", abort_if_locked: true { |client|
            ::Moongoon::Log.info { "Creating indexes for collection #{collection} (db: #{database})." }
            client[database][collection].create_indexes(models: indexes)
          }
        rescue e
          ::Moongoon::Log.error { "Error while creating indexes for collection #{collection}.\n#{e}\n#{indexes.to_json}" }
        end
      }
    }
  end

  macro included
    {% verbatim do %}

    # Defines an index that will be applied to this Model's underlying mongo collection.
    #
    # **Note that the order of fields do matter.**
    #
    # If not provided the name of the index is generated automatically from the keys names and order.
    #
    # Please have a look at the [MongoDB documentation](https://docs.mongodb.com/manual/reference/command/createIndexes/)
    # for more details about index creation and the list of available index options.
    #
    # ```
    # # Specify one or more fields with a type (ascending or descending order, text indexing…)
    # index field1: 1, field2: -1
    # # Set the unique argument to create a unique index.
    # index field: 1, options: {unique: true}
    # ```
    def self.index(
      collection : String? = nil,
      database : String? = nil,
      options = NamedTuple.new,
      name : String? = nil,
      **keys
    ) : Nil
      index = BSON.new({
        keys:  keys,
        options: !name ? options : options.merge({ name: name })
      })
      cb = ->{ {(database || self.database_name).not_nil!, (collection || self.collection_name).not_nil!} }
      ::Moongoon::Traits::Database::Indexes.add_index(index, cb)
    end

    # :ditto:
    def self.index(
      keys : Hash(String, BSON::Value),
      collection : String? = nil,
      database : String? = nil,
      options = Hash(String, BSON::Value).new,
      name : String? = nil
    ) : Nil
      index = BSON.new({
        "keys"  => keys,
        "options" => !name ? options : options.merge({ "name" => name })
      })
      cb = ->{ {(database || self.database_name).not_nil!, (collection || self.collection_name).not_nil!} }
      ::Moongoon::Traits::Database::Indexes.add_index(index, cb)
    end

    {% end %}
  end
end
