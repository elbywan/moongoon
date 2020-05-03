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
    def remove(query = BSON.new, **args) : Nil
      id_check!
      model = self
      full_query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_id_filter id.not_nil!)
      @@before_remove.each { |cb| cb.call(model).try{|m| model = m} }
      ::Moongoon.connection { |db|
        db[@@collection].remove(full_query.to_bson, **args)
      }
      @@after_remove.each { |cb| cb.call(model).try{|m| model = m} }
    end

    # Removes one or more documents from the collection.
    #
    # ```
    # User.remove({ name: { "$in": ["John", "Jane"] }})
    # ```
    def self.remove(query = BSON.new, **args) : Nil
      @@before_remove_static.each { |cb| cb.call(query.to_bson) }
      ::Moongoon.connection { |db|
        db[@@collection].remove(query.to_bson, **args)
      }
      @@after_remove_static.each { |cb| cb.call(query.to_bson) }
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
      full_query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_id_filter id)
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
      full_query = query.to_bson.clone.concat(::Moongoon::Traits::Database::Internal.build_ids_filter ids)
      remove(full_query)
    end

    # Clears the collection.
    #
    # NOTE: **Use with caution!**
    #
    # Will remove all the documents in the collection.
    def self.clear : Nil
      ::Moongoon.connection { |db|
        db[@@collection].remove(({} of String => BSON).to_bson)
      }
    end
  end
end
