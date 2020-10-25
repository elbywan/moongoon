require "log"
require "cryomongo"

require "./config"
require "./errors"
require "./database"
require "./models"

# Moongoon is a MongoDB object-document mapper library.
module Moongoon
  Log = ::Log.for(self)

  extend Moongoon::Database
end
