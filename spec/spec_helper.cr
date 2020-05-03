require "spec"
require "../src/moongoon"

backend = Log::IOBackend.new
Log.builder.bind "*", :debug, backend

::Moongoon.after_connect_before_scripts {
  ::Moongoon.connection { |db|
    db.drop
  }
}
::Moongoon.connect(
  database_name: "moongoon_test"
)
