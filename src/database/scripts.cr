# This module handles database migration scripts.
module Moongoon::Database::Scripts
  SCRIPT_CLASSES = [] of Class

  # Base database script class.
  #
  # ### Example
  #
  # ```
  # class Moongoon::Database::Scripts::Test < Moongoon::Database::Scripts::Base
  #   # Scripts run in ascending order.
  #   # Default order if not specified is 1.
  #   order Time.utc(2020, 3, 11).to_unix
  #
  #   def process(db : Mongo::Database)
  #     # Dummy code that will add a ban flag for users that are called 'John'.
  #     # This code uses the `mongo.cr` driver shard syntax, but Models could
  #     # be used for convenience despite a performance overhead.
  #     db["users"].update(
  #       selector: {name: "John"},
  #       update: {"$set": {"banned": true}},
  #       flags: LibMongoC::UpdateFlags::MULTI_UPDATE
  #     )
  #   end
  # end
  # ```
  #
  # ### Usage
  #
  # Any class that inherits from `Moongoon::Database::Scripts::Base` will be registered as a script.
  #
  # Calling `Moongoon::Database::Scripts.process` will attempt to run scripts once and write the status in the `scripts` collection of the database.
  # If multiple servers are launched at the same time they will wait until all the scripts are processed and resume execution once it's done.
  abstract class Base
    abstract def process(db : Mongo::Database)

    macro inherited
      {% verbatim do %}
        {% Moongoon::Database::Scripts::SCRIPT_CLASSES << @type %}

        class_property order : Int64 = 1

        private macro order(nb)
          @@order = {{nb}}
        end

        # Process a registered script.
        def self.process(db : Mongo::Database)
          script_class_name = {{ @type.stringify }}

          return if db["scripts"].find_one({ name: script_class_name }.to_bson)

          ::Moongoon::Log.info { "Running script '#{script_class_name}'" }

          db["scripts"].insert({ name: script_class_name, date: Time.utc.to_rfc3339, status: "running" }.to_bson)
          {{ @type }}.new.process(db)
          db["scripts"].update({ name: script_class_name }.to_bson, { "$set": { status: "done" }}.to_bson)
        rescue e
          ::Moongoon::Log.error { "Error while running script '#{script_class_name}'\n#{e.message.to_s}" }
          db["scripts"].update({ name: script_class_name }.to_bson, { "$set": { status: "error", error: e.message.to_s }}.to_bson)
        end
      {% end %}
    end
  end

  # Process every registered script.
  #
  # For each registered script the following steps will be executed:
  #
  # - Perform a lookup in the `scripts` collection to check whether the script has already been executed.
  # - If not, then attempt to run it.
  # - If another process is running the script already, will wait for completion and resume execution.
  # - Log the result of the script in the database and go on.
  def self.process(_db : Mongo::Database)
    ::Moongoon::Log.info { "Processing database scripts…" }
    callbacks = [] of {Int64, Proc(Mongo::Database, Nil)}
    {% for script in SCRIPT_CLASSES %}
      callbacks << { {{script}}.order, ->{{script}}.process(Mongo::Database) }
    {% end %}
    callbacks.sort! { |a, b| a[0] <=> b[0] }
    callbacks.each { |_, cb|
      ::Moongoon.connection_with_lock "scripts" { |db|
        cb.call(db)
      }
    }
  end
end
