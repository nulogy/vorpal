require "vorpal/version"
require "vorpal/configuration"

# Allows easy creation of {Vorpal::AggregateRepository}
# instances.
#
# ```ruby
# repository = Vorpal.define do
#   map Tree do
#     fields :name
#     belongs_to :trunk
#     has_many :branches
#   end
#
#   map Trunk do
#     fields :length
#     has_one :tree
#   end
#
#   map Branch do
#     fields :length
#     belongs_to :tree
#   end
# end
# ```
module Vorpal
  extend Vorpal::Configuration
end
