# :nodoc:
module Moongoon::Traits::Database::Methods::Post
  macro included

    # Inserts this model instance in the database.
    #
    # The `_id` field is generated during the insertion process.
    #
    # ```
    # user = User.new name: "John", age: 25
    # user.insert
    # ```
    def insert(**args) : self
      self._id = BSON::ObjectId.new
      @@before_insert.each { |cb| cb.call(self) }
      ::Moongoon.connection { |db|
        db[@@collection].insert(self.to_bson, **args)
      }
      @@after_insert.each { |cb| cb.call(self) }
      self
    end

    # Inserts multiple model instances in the database.
    #
    # The `_id` field is generated during the insertion process.
    #
    # ```
    # john = User.new name: "John", age: 25
    # jane = User.new name: "Jane", age: 22
    # User.bulk_insert [john, jane]
    # ```
    def self.bulk_insert(self_array : Indexable(self), **args) : Indexable(self)
      ::Moongoon.connection { |db|
        collection = db[@@collection]
        bo = collection.create_bulk_operation(**args)
        self_array.each { |model|
          model._id = BSON::ObjectId.new
          @@before_insert.each { |cb| cb.call(model) }
          bo.insert(model.to_bson)
        }
        bo.execute
        self_array.each { |model|
          @@after_insert.each { |cb| cb.call(model) }
        }
      }
      self_array
    end
  end
end
