require 'ruby-prof'

# In order to use these helpers do the following:
# 1) Add `spec.add_development_dependency "ruby-prof"` to the vorpal.gemspec file.
# 2) Do a `bundle update`
# 3) Add `require 'helpers/profile_helpers'` to the spec where you wish to profile.
module ProfileHelpers
  module_function

  # Runs a block a given number of times and outputs the profiling results in a 'Call Tree'
  # format suitable for display by a tool like KCacheGrind.
  #
  # - Installing QCacheGrind on OSX: http://nickology.com/2014/04/16/view-xdebug-cachegrind-files-on-mac-os/
  def output_callgrind(description, times=1, &block)
    RubyProf.measure_mode = RubyProf::PROCESS_TIME
    RubyProf.start

    times.times(&block)

    result = RubyProf.stop
    printer = RubyProf::CallTreePrinter.new(result)
    File.open("#{description}_#{DateTime.now.strftime("%FT%H:%M:%S%z")}.callgrind", "w") do |file|
      printer.print(file)
    end
  end
end