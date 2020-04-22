module Moongoon::Error
end

# Raised when a query fails to retrieve documents.
class Moongoon::Error::NotFound < Exception
end
