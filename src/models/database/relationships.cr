# :nodoc:
module Moongoon::Traits::Database::Relationships
  macro included
    {% verbatim do %}
    # References one or more documents belonging to another collection.
    #
    # Creates a model field that will reference either one or multiple
    # foreign documents depending on the arguments provided.
    #
    # NOTE: This macro is useful when using named arguments to keep the reference
    # in sync when documents are added or removed from the other collection.
    #
    # ```
    # class MyModel < Moongoon::Collection
    #   # The following references are not kept in sync because extra named arguments are not used.
    #
    #   # Reference a single user.
    #   reference user_id, model: User
    #
    #   # References multiple users.
    #   reference user_ids, model: User, many: true
    #
    #   reference user_ids, model: User, many: true
    # end
    # ```
    #
    # **Named arguments**
    #
    # - *model*: The referenced model class.
    # - *many*: Set to true to reference multiple documents.
    # - *delete_cascade*: If true, removes the referenced document(s) when this model is removed.
    # - *clear_reference*: If true, sets the reference to nil (if referencing a single document), or removes the id from the
    # reference array (if referencing multiple documents) when the referenced document(s) are removed.
    # - *back_reference*: The name of the refence, if it exists, in the referenced model that back-references this model.
    # If set, when a referenced document gets inserted, this reference will be updated to add the newly created id.
    #
    # ```
    # class MyModel < Moongoon::Collection
    #   # Now some examples that are using extra arguments.
    #
    #   # References a single user from the User model class.
    #   # The user has a field that links to back to this model (best_friend_id).
    #   # Whenever a user is inserted, the reference will get updated to point to the linked user.
    #   reference user_id, model: User, back_reference: best_friend_id
    #
    #   # References multiple pets. When this model is removed, all the pets
    #   # referenced will be removed as well.
    #   reference pet_ids, model: Pet, many: true, delete_cascade: true
    #
    #   # Whenever a Pet is removed the reference will get updated and the
    #   # id of the Pet will be removed from the array.
    #   reference pet_id, model: Pet, many: true, clear_reference: true
    # end
    # ```
    macro reference(
      # Name of the field in the model
      field,
      *,
      model,
      many = false,
      delete_cascade = false,
      clear_reference = false,
      # Set with the target collection field name (back-reference) to update when the referenced model gets inserted.
      # Field name must be equal to the instance variable referencing this model from the target model.
      back_reference = nil
    )
      {% field_key = field.id %}
      {% model_class = model %}

      {% if many %}
        # References multiple documents
        property {{ field_key }} : Array(String) = [] of String

        {% if delete_cascade %}
          # Cascades on deletion

          self.before_remove { |model|
            model = model.fetch
            ids_to_remove = model.try &.{{ field_key }}
            if ids_to_remove.try(&.size) || 0 > 0
              {{ model_class }}.remove_by_ids ids_to_remove.not_nil!
            end
          }

          self.before_remove_static { |query|
            models = find query
            ids_to_remove = [] of String
            models.each { |model|
              model.{{ field_key }}.try &.each { |id|
                ids_to_remove << id
              }
            }
            if ids_to_remove.size > 0
              {{ model_class }}.remove_by_ids ids_to_remove
            end
          }
        {% end %}

      {% else %}
        # References a single item
        property {{ field_key }} : String?

        {% if delete_cascade %}
          # Cascades on deletion

          self.before_remove { |model|
            model = model.fetch
            link = model.try &.{{ field_key }}
            if link
              {{ model_class }}.remove_by_id link
            end
          }

          self.before_remove_static { |query|
            models = find query
            ids_to_remove = [] of String
            models.each { |model|
              if id_to_remove = model.{{ field_key }}
                ids_to_remove <<  id_to_remove
              end
            }
            if ids_to_remove.size > 0
              {{ model_class }}.remove_by_ids ids_to_remove
            end
          }
        {% end %}

      {% end %}

      {% if clear_reference %}
        # Updates the reference when the target gets deleted.
        {% if many %}
          {% mongo_op = "$pull" %}
        {% else %}
          {% mongo_op = "$unset" %}
        {% end %}

        {{ model_class }}.after_remove { |removed_model|
          items = self.find({
            {{ field_key }}: removed_model.id
          })
          if items.size > 0
            ids = items.map &.id!
            self.update_by_ids(ids, {
              {{ mongo_op }}: {
                {{ field_key }}: removed_model.id
              }
            })
          end
        }
        {{ model_class }}.before_remove_static { |query|
          removed_models = {{ model_class }}.find query
          removed_models_ids = removed_models.map &.id!
          items = self.find({
            {{ field_key }}: {
              "$in": removed_models_ids
            }
          })
          if items.size > 0
            ids = items.map &.id!
            self.update_by_ids(ids, {
              {{ mongo_op }}: {
                {{ field_key }}: {
                  "$in": removed_models_ids
                }
              }
            })
          end
        }
      {% end %}

      {% if back_reference %}
        # Updates the reference when a target back-referencing this model gets inserted.
        {{ model_class }}.after_insert { |inserted_model|
          sync_field = inserted_model.{{back_reference.id}}
          if sync_field
            self.update_by_id(sync_field, {
              {% if many %}
                "$addToSet": {
                  {{ field_key }}: inserted_model.id
                }
              {% else %}
                "$set": {
                  {{ field_key }}: inserted_model.id
                }
              {% end %}
            })
          end
        }
      {% end %}
    end
    {% end %}
  end
end
