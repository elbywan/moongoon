require "spec"
require "../src/moongoon"

::Moongoon.after_connect_before_scripts { |db|
  db.drop
}
::Moongoon.connect(
  database_name: "moongoon_test"
)
