# :nodoc:
module Moongoon::Traits::Database::Internal
  extend self

  # Query builders #

  protected def self.format_aggregation(query, stages, fields = nil, order_by = nil, skip = 0, limit : Int? = nil)
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
    if (l = limit) && l > 0
      pipeline << BSON.new({"$limit": l.to_i32})
    end
    pipeline
  end

  protected def self.concat_id_filter(query, id : BSON::ObjectId | String | Nil)
    BSON.new({"_id": self.bson_id(id)}).append(BSON.new(query))
  end

  protected def self.concat_ids_filter(query, ids : Array(BSON::ObjectId?) | Array(String?))
    BSON.new({
      "_id" => {
        "$in" => ids.map { |id|
          self.bson_id(id)
        }.compact,
      },
    }).append(BSON.new(query))
  end

  # Validation helpers #

  # Raises if the Model has a nil id field.
  private def id_check!
    raise ::Moongoon::Error::NotFound.new unless self._id
  end

  protected def self.bson_id(id : String | BSON::ObjectId | Nil)
    case id
    when String
      id.blank? ? nil : BSON::ObjectId.new(id)
    when BSON::ObjectId
      id
    when Nil
      nil
    end
  end
end
