require "json"

require "./database"

# Models are classes used to store data and interact with the database.
module Moongoon
  # Base model class.
  #
  # Contains helpers to (de)serialize data to json format and bson format.
  #
  # ```
  # class Models::MyModel < Moongoon::Document
  #   property name : String
  #   property age : Int32
  # end
  # ```
  abstract class Document
    include JSON::Serializable
    include BSON::Serializable

    # Creates a new instance of the class from variadic arguments.
    #
    # ```
    # User.new first_name: "John", last_name: "Doe"
    # ```
    def self.new(**args)
      instance = self.allocate
      {% for ivar in @type.instance_vars %}
        {% default_value = ivar.default_value %}
        {% if ivar.type.nilable? %}
          instance.{{ivar.id}} = args["{{ivar.id}}"]? {% if ivar.has_default_value? %}|| {{ default_value }}{% end %}
        {% else %}
          if value = args["{{ivar.id}}"]?
            instance.{{ivar.id}} = value
          {% if ivar.has_default_value? %}
          else
            instance.{{ivar.id}} = {{ default_value }}
          {% end %}
          end
        {% end %}
      {% end %}
      instance
    end

    # Instantiate a named tuple from the model instance properties.
    #
    # ```
    # user = User.new first_name: "John", last_name: "Doe"
    # pp user.to_tuple
    # # => {
    # #   first_name: "John",
    # #   last_name: "Doe",
    # # }
    # ```
    def to_tuple
      {% begin %}
      {
      {% for ivar in @type.instance_vars %}
        "{{ ivar.name }}": self.{{ ivar.name }},
      {% end %}
      }
      {% end %}
    end
  end

  # :nodoc:
  abstract class MongoBase < Document
    # Sets the underlying MongoDB collection name.
    private macro collection(value)
      class_property collection : String = {{ value }}
    end

    # The MongoDB internal id representation.
    property _id : BSON::ObjectId?

    # Set a MongoDB bson _id from a String.
    def id=(id : String)
      self._id = BSON::ObjectId.new id
    end

    # Converts the MongoDB bson _id to a String representation.
    def id
      self._id.to_s if self._id
    end

    # Converts the MongoDB bson _id to a String representation.
    #
    # Will raise if _id is nil.
    def id!
      self._id.to_s.not_nil!
    end
  end

  # Base model class for interacting with a MongoDB collection.
  #
  # This abstract class extends the `Moongoon::Base` class and enhances it with
  # utility methods and macros used to query, update and configure an
  # underlying MongoDB collection.
  #
  # ```
  # class MyModel < Moongoon::Collection
  #   collection "my_models"
  #
  #   index name: 1, options: {unique: true}
  #
  #   property name : String
  #   property age : Int32
  # end
  # ```
  abstract class Collection < MongoBase
    include ::Moongoon::Traits::Database::Full

    # Include this module to enable resource versioning.
    module Versioning
      include ::Moongoon::Traits::Database::Versioning

      macro included
        extend Static

        {% base_versioning_name = @type.stringify.split("::")[-1].underscore %}
        @@versioning_id_field = {{(base_versioning_name + "_id")}}
        @@versioning_transform : Proc(BSON, BSON, BSON)? = nil

        index({
          @@versioning_id_field => 1
        }, "#{@@collection}_history")
      end
    end
  end

  # A limited model class for interacting with a MongoDB collection.
  #
  # NOTE: Similar to `Moongoon::Collection` but can only be used to update a MongoDB collection.
  #
  # ```
  # class Partial < Moongoon::Collection::UpdateOnly
  #   collection "my_models"
  #
  #   property name : String?
  #   property age : Int32?
  # end
  # ```
  abstract class Collection::UpdateOnly < MongoBase
    include ::Moongoon::Traits::Database::Update
  end

  # A limited model class for interacting with a MongoDB collection.
  #
  # NOTE: Similar to `Moongoon::Collection` but can only be used to query a MongoDB collection.
  #
  # ```
  # class ReadOnly < Models::Collection::ReadOnly
  #   collection "my_models"
  #
  #   property name : String?
  #   property age : Int32?
  # end
  # ```
  abstract class Collection::ReadOnly < MongoBase
    include ::Moongoon::Traits::Database::Read
  end
end
