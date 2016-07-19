require "vorpal/version"
require "vorpal/dsl/configuration"

# Allows easy creation of {Vorpal::Engine} instances.
#
# ```ruby
# engine = Vorpal.define do
#   map Tree do
#     attributes :name
#     belongs_to :trunk
#     has_many :branches
#   end
#
#   map Trunk do
#     attributes :length
#     has_one :tree
#   end
#
#   map Branch do
#     attributes :length
#     belongs_to :tree
#   end
# end
#
# mapper = engine.mapper_for(Tree)
# ```
module Vorpal
  extend Vorpal::Dsl::Configuration
end
