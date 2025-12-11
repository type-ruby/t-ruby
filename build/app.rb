# Application entry point
  name: String,
  version: String,
  debug: Boolean
}

def initialize_app(config)
  puts "Initializing #{config[:name]}"
  true
end

def run(args)
  0
end
