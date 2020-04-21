require "spec"
require "../src/moongoon"

class Model < Moongoon::Collection
  collection "models"

  property name : String
end

::Moongoon.after_connect_before_scripts { |db|
  db.drop
}
::Moongoon.connect(
  database_name: "moongoon_test"
)
