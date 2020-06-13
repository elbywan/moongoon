# :nodoc:
module Moongoon::Traits::Database::Methods::Delete
  macro included

    # Removes one document having the same id as this model.
    #
    # Matches on `self.id`.
    #
    # ```
    # user = User.find_by_id 123456
    # user.remove
    # ```
    #
    # It is possible to add query filters to conditionally prevent removal.
    #
    # ```
    # # Remove the user only if he/she is named John
    # user.remove({ name: "John" })
    # ```
    def remove(query = BSON.new, no_hooks = false, **args) : Nil
      id_check!
      full_query = ::Moongoon::Traits::Database::Internal.concat_id_filter(query, id!)
      self.class.before_remove_call(self) unless no_hooks
      self.class.collection.delete_one(full_query, **args)
      self.class.after_remove_call(self) unless no_hooks
    end

    # Removes one or more documents from the collection.
    #
    # ```
    # User.remove({ name: { "$in": ["John", "Jane"] }})
    # ```
    def self.remove(query = BSON.new, no_hooks = false, **args) : Nil
      self.before_remove_static_call(BSON.new query) unless no_hooks
      self.collection.delete_many(query, **args)
      self.after_remove_static_call(BSON.new query) unless no_hooks
    end

    # Removes one document by id.
    #
    # ```
    # id = 123456
    # User.remove_by_id id
    # ```
    #
    # It is possible to add query filters to conditionally prevent removal.
    #
    # ```
    # # Remove the user only if he/she is named John
    # User.remove id, query: { name: "John" }
    # ```
    def self.remove_by_id(id, query = BSON.new, **args) : Nil
      full_query = ::Moongoon::Traits::Database::Internal.concat_id_filter(query, id)
      remove(full_query)
    end

    # Removes one or more documents from the collection by their ids.
    # ```
    # ids = ["1", "2", "3"]
    # User.remove_by_ids ids
    # ```
    #
    # It is possible to add query filters to conditionally prevent removal.
    #
    # ```
    # # Remove the users only if they are named John
    # User.remove_by_ids ids , query: { name: "John" }
    # ```
    def self.remove_by_ids(ids, query = BSON.new, **args) : Nil
      full_query = ::Moongoon::Traits::Database::Internal.concat_ids_filter(query, ids)
      remove(full_query)
    end

    # Clears the collection.
    #
    # NOTE: **Use with caution!**
    #
    # Will remove all the documents in the collection.
    def self.clear : Nil
      self.collection.delete_many(BSON.new)
    end
  end
end
