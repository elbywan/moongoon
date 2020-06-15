require "spec"
require "../src/moongoon"

::Moongoon.after_connect_before_scripts {
  ::Moongoon.connection { |db|
    db.drop
  }
}
::Moongoon.connect(
  database_name: "moongoon_test"
)
