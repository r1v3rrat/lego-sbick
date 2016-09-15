# lego-sbrick
A ruby library for interfacing with the LEGO® compatible Power Functions bluetooth SBrick

# PRE Alpha... checking in code so I can work on it from my raspberry pi.  Planning to submit to rubygems by the end of sept.  For now take a look.  I'll be refactoring repo for rubygems format in the next couple days

```ruby
# (1) make sure you have bluetooth 4+, know your bluethooth interface, address of your sbrick
#More info: https://social.sbrick.com/wiki/view/pageId/20/slug/linux-client-scripts

# (2) Use some ruby code:

# so you can see what is happening
Logging.logger.root.appenders = Logging.appenders.stdout
Logging.logger.root.level = :debug

# create object with your local interface and the remote address to the sbrick
b = SBrick.new("hci0","00:07:80:D0:57:C3")
b.version
b.uptime
b.resets
b.temperature
b.voltage
b.led_test

# who cares about voltage and tempature?  Lets burn some rubber/train wheels...
# control all 4 channels with a single command...

b.quick_drive([100,-50,:fw,:brake])
# channel 0 -> 100% power clockwise
# channel 0 -> 50% power counter clockwise
# channel 2 -> free wheel... cut power but do not brake
# channel 3 -> brake

```

