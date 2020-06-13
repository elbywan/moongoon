require "spec"
require "../src/moongoon"

# backend = Log::IOBackend.new
# Log.builder.bind "mongo.*", :trace, backend
Log.setup(:trace)

::Moongoon.after_connect_before_scripts {
  ::Moongoon.database.command(Mongo::Commands::DropDatabase)
}
::Moongoon.connect(
  database_name: "moongoon_test"
)
