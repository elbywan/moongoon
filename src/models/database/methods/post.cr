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
    def insert(no_hooks = false, **args) : self
      self._id = BSON::ObjectId.new
      self.class.before_insert_call(self) unless no_hooks
      ::Moongoon.connection { |db|
        db[@@collection].insert(self.to_bson, **args)
      }
      self.class.after_insert_call(self) unless no_hooks
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
    def self.bulk_insert(self_array : Indexable(self), no_hooks = false, **args) : Indexable(self)
      ::Moongoon.connection { |db|
        collection = db[@@collection]
        bo = collection.create_bulk_operation(**args)
        self_array.each { |model|
          model._id = BSON::ObjectId.new
          self.before_insert_call(model) unless no_hooks
          bo.insert(model.to_bson)
        }
        bo.execute
        unless no_hooks
          self_array.each { |model|
            self.after_insert_call(model)
          }
        end
      }
      self_array
    end
  end
end
