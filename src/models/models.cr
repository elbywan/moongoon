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
    #
    # NOTE: Only instance variables having associated setter methods will be initialized.
    def self.new(**args : **T) forall T
      instance = self.allocate
      {% begin %}
        {% for ivar in @type.instance_vars %}
          {% has_setter = @type.has_method? ivar.stringify + "=" %}
          {% default_value = ivar.default_value %}
          {% if has_setter && ivar.type.nilable? %}
            instance.{{ivar.id}} = args["{{ivar.id}}"]? {% if ivar.has_default_value? %}|| {{ default_value }}{% end %}
          {% elsif has_setter %}
            if value = args["{{ivar.id}}"]?
              instance.{{ivar.id}} = value
            {% if ivar.has_default_value? %}
            else
              instance.{{ivar.id}} = {{ default_value }}
            {% elsif !T[ivar.id] %}
              {% raise "Instance variable '" + ivar.stringify + "' cannot be initialized from " + T.stringify + "." %}
            {% end %}
            end
          {% elsif !ivar.has_default_value? %}
            {% raise "Instance variable '" + ivar.stringify + "' has no setter or default value." %}
          {% end %}
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
    #
    # NOTE: Only instance variables having associated getter methods will be returned.
    def to_tuple
      {% begin %}
      {
      {% for ivar in @type.instance_vars %}
        {% if @type.has_method? ivar.stringify + "?" %}
          "{{ ivar.name }}": self.{{ ivar.name }}?,
        {% elsif @type.has_method? ivar.stringify %}
          "{{ ivar.name }}": self.{{ ivar.name }},
        {% end %}
      {% end %}
      }
      {% end %}
    end
  end

  # :nodoc:
  abstract class MongoBase < Document
    module Validation
      macro included
        include Moongoon::Traits::Database::Validators
      end
    end

    macro inherited
      class_getter database_name : String do
        Moongoon.database_name
      end

      class_getter database : Mongo::Database do
        if @@database_name == Moongoon.database_name
          Moongoon.database
        else
          Moongoon.client[database_name]
        end
      end
      class_getter collection : Mongo::Collection do
        self.database[collection_name]
      end

      # Sets the MongoDB database name.
      private macro database(value)
        @@database_name = \{{ value }}
      end

      # Sets the MongoDB collection name.
      private macro collection(value)
        class_getter collection_name : String = \{{ value }}
      end

      # Returns true if the document has been removed from the db
      @[JSON::Field(ignore: true)]
      @[BSON::Field(ignore: true)]
      getter? removed = false

      # Returns true if the document has been inserted and not yet removed
      def persisted?
        self.inserted? && !self.removed?
      end

      # Returns true if the document has been inserted (i.e. has an id)
      def inserted?
        self._id != nil
      end

      # The MongoDB internal id representation.
      property _id : BSON::ObjectId?

      # Returns the MongoDB bson _id
      #
      # Will raise if _id is nil.
      def _id!
        self._id.not_nil!
      end

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
        self.id.not_nil!
      end
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
  #   index keys: {name: 1}, options: {unique: true}
  #
  #   property name : String
  #   property age : Int32
  # end
  # ```
  abstract class Collection < MongoBase
    include ::Moongoon::Traits::Database::Full

    # Copying and hacking BSON::Serializable for now - but ideally we'd just add more flexibility there? (options[force_emit_nil: true] or something?)
    def unsets_to_bson : BSON?
      bson = BSON.new
      {% begin %}
      {% global_options = @type.annotations(BSON::Options) %}
      {% camelize = global_options.reduce(false) { |_, a| a[:camelize] } %}
      {% for ivar in @type.instance_vars %}
        {% ann = ivar.annotation(BSON::Field) %}
        {% key = ivar.name %}
        {% bson_key = ann ? ann[:key].id : camelize ? ivar.name.camelcase(lower: camelize == "lower") : ivar.name %}
        {% unless ann && ann[:ignore] %}
          {% unless ann && ann[:emit_null] %} #confusing, but it will be picked up by normal to_bson so we don't need it here
            if self.{{ key }}.nil?
              bson["{{ bson_key }}"] = nil
            end
          {% end %}
        {% end %}
      {% end %}
      {% end %}
      bson.empty? ? nil : bson
    end

    # Include this module to enable resource versioning.
    module Versioning
      include ::Moongoon::Traits::Database::Versioning

      macro included
        extend Static

        {% base_versioning_name = @type.stringify.split("::")[-1].underscore %}
        @@versioning_id_field = {{(base_versioning_name + "_id")}}
        @@versioning_transform : Proc(BSON, BSON, BSON)? = nil

        # Get the versioning collection.
        def self.history_collection
          self.database["#{self.collection_name}_history"]
        end
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
