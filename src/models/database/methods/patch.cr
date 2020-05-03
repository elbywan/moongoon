# :nodoc:
module Moongoon::Traits::Database::Methods::Patch
  macro included
    # Updates a document having the same id as this model with the data stored in `self`.
    #
    # Tries to match on `self.id`.
    #
    # ```
    # user = User.new name: "John", age: 25
    # user.insert
    # user.age = 26
    # user.update
    # ```
    #
    # It is possible to add query filters to conditionally prevent an update.
    #
    # ```
    # user = User.new name: "John", locked: true
    # user.insert
    # user.name = "Igor"
    # # Prevents updating users that are locked.
    # user.update({ locked: false })
    # pp User.find_by_id(user.id.not_nil!).to_json
    # # => { "id": "some id", "name": "John", "locked": true }
    # ```
    def update(query = BSON.new, **args) : self
      id_check!
      full_query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_id_filter id.not_nil!)
      self.update_query(full_query, **args)
    end

    # Updates one or more documents in the underlying collection.
    #
    # Every document matching the *query* argument will be updated.
    # See the [MongoDB tutorial](https://docs.mongodb.com/v3.6/tutorial/update-documents/)
    # for more information about the syntax.
    #
    # ```
    # # Rename every person named "John" to "Igor".
    # User.update(query: { name: "John" }, update: { "$set": { name: "Igor" } })
    # ```
    def self.update(query, update, no_hooks = false, **args) : Nil
      self.before_update_static_call(query.to_bson, update.to_bson) unless no_hooks
      ::Moongoon.connection { |db|
        db[@@collection].update(query.to_bson, update.to_bson, **args, flags: LibMongoC::UpdateFlags::MULTI_UPDATE)
      }
      self.after_update_static_call(query.to_bson, update.to_bson) unless no_hooks
    end

    # Updates one or more documents with the data stored in `self`.
    #
    # Every document matching the *query* argument will be updated.
    #
    # ```
    # user = User.new name: "John", age: 25
    # user = User.new name: "Jane", age: 30
    # user.insert
    # user.age = 40
    # # Updates both documents
    # user.update_query({ name: {"$in": ["John", "Jane"]} })
    # ```
    def update_query(query, no_hooks = false, **args) : self
      self.class.before_update_call(self) unless no_hooks
      ::Moongoon.connection { |db|
        db[@@collection].update(
          query.to_bson,
          **args,
          update: {"$set" => self.to_bson}.to_bson,
          flags: LibMongoC::UpdateFlags::MULTI_UPDATE
        )
      }
      self.class.after_update_call(self) unless no_hooks
      self
    end

    # Updates one document by id.
    #
    # Similar to `self.update`, except that a matching on the `_id`
    # field will be added to the *query* argument.
    #
    # ```
    # id = 123456
    # User.update_by_id(id, { "$set": { "name": "Igor" }})
    # ```
    #
    # It is possible to add query filters to conditionally prevent an update.
    #
    # ```
    # # Updates the user only if he/she is named John.
    # User.update_by_id(id, query: { name: "John" }, update: { "$set": { name: "Igor" }})
    # ```
    def self.update_by_id(id, update, query = BSON.new, **args) : Nil
      full_query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_id_filter id)
      update(full_query, update, **args)
    end

    # Updates one or multiple documents by their ids.
    #
    # Similar to `self.update`, except that a matching on multiple `_id`
    # fields will be added to the *query* argument.
    #
    # ```
    # ids = ["1", "2", "3"]
    # User.update_by_ids(ids, { "$set": { "name": "Igor" }})
    # ```
    #
    # It is possible to add query filters.
    #
    # ```
    # # Updates the users only if they are named John.
    # User.update_by_ids(ids, query: { name: "John" }, update: { "$set": { name: "Igor" }})
    # ```
    def self.update_by_ids(ids, update, query = BSON.new, **args) : Nil
      full_query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_ids_filter ids)
      update(full_query, update, **args)
    end

    # Modifies and returns a single document.
    #
    # See the [official documentation](https://docs.mongodb.com/v3.6/reference/command/findAndModify/).
    #
    # ```
    # User.find_and_modify({ name: "John" }, { "$set": { "name": "Igor" }})
    # ```
    def self.find_and_modify(query, update, fields = BSON.new, **args)
      item = ::Moongoon.connection { |db|
        db[@@collection].find_and_modify(query.to_bson, update.to_bson, **args, fields: fields.to_bson)
      }
      self.new item if item
    end

    # Modifies and returns a single document.
    #
    # Similar to `self.update`, except that a matching on the `_id`
    # field will be added to the *query* argument.
    def self.find_and_modify_by_id(id, update, query = BSON.new, **args)
      full_query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_id_filter id)
      find_and_modify(full_query, update, **args)
    end
  end
end
