# :nodoc:
module Moongoon::Traits::Database::Methods::Patch
  macro included
    @@default_fields : BSON? = nil

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
    # It is possible to add *query* filters to conditionally prevent an update.
    #
    # ```
    # user = User.new name: "John", locked: true
    # user.insert
    # user.name = "Igor"
    # # Prevents updating users that are locked.
    # user.update({ locked: false })
    # pp User.find_by_id(user.id!).to_json
    # # => { "id": "some id", "name": "John", "locked": true }
    # ```
    #
    # The update can be restricted to specific *fields*.
    #
    # ```
    # user = User.new name: "John", age: 25
    # user.insert
    # user.age = 26
    # user.name = "Tom"
    # # Updates only the age field.
    # user.update(fields: {:age})
    # ```
    def update(query = BSON.new, **args) : self
      id_check!
      query = ::Moongoon::Traits::Database::Internal.concat_id_filter(query, _id!)
      self.update_query(query, **args)
    end

    # Update specific fields both in the model and in database.
    #
    # ```
    # user = User.new name: "John", age: 25
    # user.insert
    # # Updates only the age field.
    # user.update({age: 26})
    # ```
    def update_fields(fields : F, **args) : self forall F
      {% verbatim do %}
      {% begin %}
        {% for k in F.keys %}
          self.{{k}} = fields[{{k.symbolize}}]
        {% end %}
        self.update(**args, fields: {{F.keys.map(&.symbolize)}})
        {% end %}
      {% end %}
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
    def self.update(query, update, no_hooks = false, **args) : Mongo::Commands::Common::UpdateResult?
      query, update = BSON.new(query), BSON.new(update)
      unless no_hooks
        new_update = self.before_update_static_call(query, update)
        update = new_update if new_update
      end
      result = self.collection.update_many(query, update, **args)
      self.after_update_static_call(query, update) unless no_hooks
      result
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
    def update_query(query, fields = nil, no_hooks = false, **args) : self
      self.class.before_update_call(self) unless no_hooks
      changes = BSON.new

      sets = self.to_bson
      if fields
        sets = ::Moongoon::Traits::Database::Internal.filter_bson(sets, fields)
      end
      changes["$set"] = sets unless sets.empty?

      if ::Moongoon.config.unset_nils && (unsets = self.unsets_to_bson)
        if fields
          unsets = ::Moongoon::Traits::Database::Internal.filter_bson(unsets, fields)
        end
        changes["$unset"] = unsets unless unsets.empty?
      end
      self.class.collection.update_many(
        query,
        **args,
        update: changes
      )
      self.class.after_update_call(self) unless no_hooks
      self
    end

    # Updates one document by id.
    #
    # Similar to `self.update`, except that a matching on the `_id` field will be added to the *query* argument.
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
    def self.update_by_id(id : BSON::ObjectId | String, update, query = BSON.new, **args) : Mongo::Commands::Common::UpdateResult?
      query = ::Moongoon::Traits::Database::Internal.concat_id_filter(query, id)
      update(query, update, **args)
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
    def self.update_by_ids(ids, update, query = BSON.new, **args) : Mongo::Commands::Common::UpdateResult?
      query = ::Moongoon::Traits::Database::Internal.concat_ids_filter(query, ids)
      update(query, update, **args)
    end

    # Modifies and returns a single document.
    #
    # See the [official documentation](https://docs.mongodb.com/v3.6/reference/command/findAndModify/).
    #
    # ```
    # User.find_and_modify({ name: "John" }, { "$set": { "name": "Igor" }})
    # ```
    def self.find_and_modify(query, update, fields = @@default_fields, no_hooks = false, **args)
      query, update = BSON.new(query), BSON.new(update)
      unless no_hooks
        new_update = self.before_update_static_call(query, update)
        update = new_update if new_update
      end
      item = self.collection.find_one_and_update(query, update, **args, fields: fields)
      self.after_update_static_call(query, update) unless no_hooks
      self.new item if item
    end

    # Modifies and returns a single document.
    #
    # Similar to `self.find_and_modify`, except that a matching on the `_id` field will be added to the *query* argument.
    def self.find_and_modify_by_id(id : BSON::ObjectId | String, update, query = BSON.new, no_hooks = false, **args)
      query = ::Moongoon::Traits::Database::Internal.concat_id_filter(query, id)
      find_and_modify(query, update, **args)
    end

    # Removes and returns a single document.
    #
    # See the [official documentation](https://docs.mongodb.com/v3.6/reference/command/findAndModify/).
    #
    # ```
    # User.find_and_remove({ name: "John" })
    # ```
    def self.find_and_remove(query, fields = @@default_fields, no_hooks = false, **args)
      query = BSON.new(query)
      unless no_hooks
        new_update = self.before_remove_static_call(query)
        update = new_update if new_update
      end
      item = self.collection.find_one_and_delete(query, **args, fields: fields)
      self.after_remove_static_call(query) unless no_hooks
      self.new item if item
    end

    # Removes and returns a single document.
    #
    # Similar to `self.find_and_remove`, except that a matching on the `_id` field will be added to the *query* argument.
    def self.find_and_remove_by_id(id, query = BSON.new, no_hooks = false, **args)
      query = ::Moongoon::Traits::Database::Internal.concat_id_filter(query, id)
      find_and_remove(query, update, **args)
    end
  end
end
