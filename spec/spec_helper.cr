require "spec"
require "../src/moongoon"

# Define scripts and indexes before connection

class Moongoon::Database::Scripts::One < Moongoon::Database::Scripts::Base
  order 1
  on_error :discard

  def process(db : Mongo::Database)
    db["scripts_collection"].insert_one({ value: 1 })
  end
end

class Moongoon::Database::Scripts::Two < Moongoon::Database::Scripts::Base
  order 2
  on_error :retry

  def process(db : Mongo::Database)
    db["scripts_collection"].replace_one({ value: 1 }, { value: 2 })
    raise "Error raised"
  end
end

class Moongoon::Database::Scripts::Three < Moongoon::Database::Scripts::Base
  order 3
  on_success :retry

  def process(db : Mongo::Database)
    db["scripts_collection"].replace_one({ value: 2 }, { value: 3 })
  end
end

class IndexModel < Moongoon::Collection
  collection "index_models"

  property a : String
  property b : Int32

  index a: -1, name: "a_desc"
  index _id: 1, a: 1, options: { unique: true }
  index ({ "_id" => 1, "$**" => "text" })
  index ({ "b" => 1 }), name: "index_name", options: { "unique" => true }
end

::Moongoon.after_connect_before_scripts {
  ::Moongoon.database.command(Mongo::Commands::DropDatabase)
}
::Moongoon.connect(
  database_name: "moongoon_test"
)
