require "vorpal/version"
require "vorpal/configuration"

# Allows easy creation of {Vorpal::AggregateRepository}
# instances.
#
# ```ruby
# repository = Vorpal.define do
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
# ```
module Vorpal
  extend Vorpal::Configuration
end
