# :nodoc:
# Adds a combination of hooks called while interacting the database.
module Moongoon::Traits::Database::Hooks
  macro included
  {% verbatim do %}
  macro inherited
    # :nodoc:
    alias SelfCallback = Proc(self, self | Nil)
    # :nodoc:
    alias ClassCallback = Proc(BSON, Nil)
    # :nodoc:
    alias ClassUpdateCallback = Proc(BSON, BSON, Nil)

    {% events = %w(insert update remove) %}
    {% prefixes = %w(before after) %}
    {% suffixes = [nil, "static"] %}

    {% for event in events %}
      {% for prefix in prefixes %}
        {% for suffix in suffixes %}
          {% identifier = prefix + "_" + event + (suffix ? ("_" + suffix) : "") %}
          {% callback_type = "SelfCallback" %}
          {% if suffix == "static" %}
            {% if event == "update" %}
              {% callback_type = "ClassUpdateCallback" %}
            {% else %}
              {% callback_type = "ClassCallback" %}
            {% end %}
          {% end %}

          @@{{ identifier.id }} = [] of {{ callback_type.id }}

          # Registers a hook that will be called **{{prefix.id}}** an **{{event.id}}** operation is performed on a `{{@type}}` instance.
          #
          # The hook registered the last will run first.
          #
          # {% if !suffix %}NOTE: This hook will trigger when the `Models::Collection#{{event.id}}` method is called.{% end %}
          # {% if suffix == "static" %}NOTE: This hook will trigger when the `Models::Collection.{{event.id}}` method is called.{% end %}
          def self.{{identifier.id}}(&cb : {{ callback_type.id }})
            @@{{ identifier.id }}.unshift cb
          end
        {% end %}
      {% end %}
    {% end %}
  end
  {% end %}
  end
end
