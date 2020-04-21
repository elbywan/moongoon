require "./*"
require "./methods/*"

# :nodoc:
module Moongoon::Traits
end

# :nodoc:
module Moongoon::Traits::Database::Full
  macro included
    include ::Moongoon::Traits::Database::Hooks
    include ::Moongoon::Traits::Database::Helpers
    include ::Moongoon::Traits::Database::Methods::Get
    include ::Moongoon::Traits::Database::Methods::Post
    include ::Moongoon::Traits::Database::Methods::Patch
    include ::Moongoon::Traits::Database::Methods::Delete
    include ::Moongoon::Traits::Database::Internal
  end
end

# :nodoc:
module Moongoon::Traits::Database::Update
  macro included
    include ::Moongoon::Traits::Database::Hooks
    include ::Moongoon::Traits::Database::Helpers
    include ::Moongoon::Traits::Database::Methods::Patch
    include ::Moongoon::Traits::Database::Internal
  end
end

# :nodoc:
module Moongoon::Traits::Database::Read
  macro included
    include ::Moongoon::Traits::Database::Hooks
    include ::Moongoon::Traits::Database::Helpers
    include ::Moongoon::Traits::Database::Methods::Get
    include ::Moongoon::Traits::Database::Internal
  end
end
