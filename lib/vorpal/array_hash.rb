module Vorpal
module ArrayHash
  def add_to_hash(h, key, values)
    if h[key].nil? || h[key].empty?
      h[key] = []
    end
    h[key].concat(Array(values))
  end
end
end
