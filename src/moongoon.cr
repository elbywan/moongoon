require "log"
require "mongo"

require "./database"
require "./models"

# Moongoon is a MongoDB object-document mapper library.
module Moongoon
  Log = ::Log.for(self)

  extend Moongoon::Database
end