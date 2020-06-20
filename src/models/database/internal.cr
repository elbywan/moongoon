# :nodoc:
module Moongoon::Traits::Database::Internal
  extend self

  # Query builders #

  protected def self.format_aggregation(query, stages, fields = nil, order_by = nil, skip = 0, limit = 0)
    pipeline = query && !query.empty? ? [
      BSON.new({"$match": BSON.new(query)}),
    ] : [] of BSON

    stages.each { |stage|
      pipeline << BSON.new(stage)
    }
    if fields
      pipeline << BSON.new({"$project": BSON.new(fields)})
    end
    if order_by
      pipeline << BSON.new({"$sort": BSON.new(order_by)})
    end
    if skip > 0
      pipeline << BSON.new({"$skip": skip.to_i32})
    end
    if limit > 0
      pipeline << BSON.new({"$limit": limit.to_i32})
    end
    pipeline
  end

  protected def self.concat_id_filter(query, id)
    BSON.new({"_id": BSON::ObjectId.new(id.not_nil!)}).append(BSON.new(query))
  end

  protected def self.concat_ids_filter(query, ids)
    BSON.new({
      "_id" => {
        "$in" => ids.map { |id|
          BSON::ObjectId.new id
        },
      },
    }).append(BSON.new(query))
  end

  # Validation helpers #

  # Raises if the Model has a nil id field.
  private def id_check!
    raise ::Moongoon::Error::NotFound.new unless self._id
  end
end
