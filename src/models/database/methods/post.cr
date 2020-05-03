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
      model = self
      model._id = BSON::ObjectId.new
      @@before_insert.each { |cb| cb.call(model).try{|m| model = m} }
      ::Moongoon.connection { |db|
        db[@@collection].insert(model.to_bson, **args)
      }
      @@after_insert.each { |cb| cb.call(model).try{|m| model = m} }
      model
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
        self_array.map! { |model|
          model._id = BSON::ObjectId.new
          @@before_insert.each { |cb| cb.call(model).try{|m| model = m} }
          bo.insert(model.to_bson)
          model
        }
        bo.execute
        self_array.map! { |model|
          @@after_insert.each { |cb| cb.call(model).try{|m| model = m} }
          model
        }
        nil
      }
      self_array
    end
  end
end
