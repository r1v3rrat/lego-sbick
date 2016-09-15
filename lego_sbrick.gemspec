Gem::Specification.new do |s|
	s.add_runtime_dependency 'hex_string', '~> 1.0', '>= 1.0.1'
	s.add_runtime_dependency 'logging', '~> 2.1', '>= 2.1.0'
  s.name        = 'lego_sbrick'
  s.version     = '0.0.1'
  s.licenses    = ['MIT']
  s.summary     = "A ruby library for interfacing with the LEGO® compatible Power Functions bluetooth SBrick"
  s.description = "A ruby library for interfacing with the LEGO® compatible Power Functions bluetooth SBrick.  Get device info and control all four motors/channels with a single command"
  s.authors     = ["Aaron S."]
  s.email       = 'r1v3rrat@users.noreply.github.com'
  s.files       = ["lib/lego_sbrick.rb"]
  s.homepage    = 'https://github.com/r1v3rrat/lego_sbrick'
end